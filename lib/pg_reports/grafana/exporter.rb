# frozen_string_literal: true

module PgReports
  module Grafana
    # Renders selected reports in Prometheus exposition format.
    # Severity is derived from REPORT_CONFIG thresholds in Dashboard::ReportsRegistry.
    class Exporter
      SEVERITY_ORDER = {"ok" => 0, "warning" => 1, "critical" => 2}.freeze
      MAX_LABEL_VALUE_LENGTH = 200
      RESERVED_LABEL_NAMES = %w[report severity row error].freeze

      MODULES = {
        queries: -> { Modules::Queries },
        indexes: -> { Modules::Indexes },
        tables: -> { Modules::Tables },
        connections: -> { Modules::Connections },
        system: -> { Modules::System },
        schema_analysis: -> { Modules::SchemaAnalysis }
      }.freeze

      def self.render
        new.render
      end

      def initialize(favorites: PgReports.config.grafana_favorites,
        cache_ttl: PgReports.config.grafana_cache_ttl,
        clock: Time)
        @favorites = normalize(favorites)
        @cache_ttl = cache_ttl
        @clock = clock
      end

      def render
        results = @favorites.map { |key, opts| collect(key, opts) }

        lines = []
        emit(lines, "pg_reports_issues", "Number of rows by severity for the report") do |emit|
          results.each do |r|
            next unless r[:ok]
            r[:severities].each { |sev, count| emit.call({report: r[:key], severity: sev}, count) }
          end
        end

        emit(lines, "pg_reports_rows", "Total rows returned by the report") do |emit|
          results.each { |r| emit.call({report: r[:key]}, r[:rows]) if r[:ok] }
        end

        emit(lines, "pg_reports_run_seconds", "Time spent collecting the report") do |emit|
          results.each { |r| emit.call({report: r[:key]}, r[:duration].round(4)) if r[:ok] }
        end

        emit(lines, "pg_reports_last_run_timestamp", "Unix timestamp of last collection") do |emit|
          results.each { |r| emit.call({report: r[:key]}, r[:timestamp]) if r[:ok] }
        end

        emit(lines, "pg_reports_up", "Whether collection succeeded (1) or failed (0)") do |emit|
          results.each do |r|
            labels = {report: r[:key]}
            labels[:error] = r[:error] unless r[:ok]
            emit.call(labels, r[:ok] ? 1 : 0)
          end
        end

        emit(lines, "pg_reports_row", "One series per row of the report (drives Grafana table panels). Each row column becomes a label.") do |emit|
          results.each do |r|
            next unless r[:ok] && r[:rows_data]
            r[:rows_data].each_with_index do |row_labels, idx|
              emit.call(row_labels.merge(report: r[:key], row: idx), 1)
            end
          end
        end

        (lines << "").join("\n")
      end

      private

      def normalize(favorites)
        case favorites
        when Hash
          favorites.each_with_object({}) { |(k, v), h| h[k.to_sym] = (v || {}).symbolize_keys }
        when Array
          favorites.each_with_object({}) { |k, h| h[k.to_sym] = {} }
        else
          {}
        end
      end

      def collect(key, opts)
        cached(key, opts) { run(key, opts) }
      rescue => e
        {key: key, ok: false, error: e.class.name, message: e.message}
      end

      def cached(key, opts)
        ttl = opts[:ttl] || @cache_ttl
        if ttl && defined?(Rails) && Rails.respond_to?(:cache) && Rails.cache
          Rails.cache.fetch("pg_reports/grafana/#{key}", expires_in: ttl) { yield }
        else
          yield
        end
      end

      def run(key, opts)
        mod = module_for(key) or raise ArgumentError, "Unknown report: #{key}"

        started = @clock.now
        args = report_args(opts)
        # Call with no arguments when there are no kwargs to forward. On Ruby 2.7
        # `public_send(key, **{})` does not reliably elide to a no-arg call, which
        # breaks report methods (and `have_received(...).with(no_args)` matchers).
        report = args.empty? ? mod.public_send(key) : mod.public_send(key, **args)
        finished = @clock.now

        {
          key: key,
          ok: true,
          rows: report.size,
          severities: severity_counts(key, report),
          rows_data: opts.fetch(:expose_rows, true) ? row_label_sets(report) : nil,
          duration: finished - started,
          timestamp: finished.to_i
        }
      end

      def row_label_sets(report)
        report.map { |row| row_to_labels(row) }
      end

      def row_to_labels(row)
        labels = {}
        row.each do |column, value|
          next if value.nil?

          name = sanitize_label_name(column.to_s)
          next if name.empty? || RESERVED_LABEL_NAMES.include?(name)

          formatted = format_label_value(value)
          next if formatted.length > MAX_LABEL_VALUE_LENGTH

          labels[name] = formatted
        end
        labels
      end

      def sanitize_label_name(name)
        cleaned = name.gsub(/[^a-zA-Z0-9_]/, "_")
        cleaned = "_#{cleaned}" if cleaned.match?(/\A[0-9]/)
        cleaned
      end

      def format_label_value(value)
        case value
        when Float then format("%g", value)
        when Time, DateTime then value.iso8601
        else value.to_s
        end
      end

      def module_for(key)
        Dashboard::ReportsRegistry::REPORTS.each do |category, info|
          next unless info[:reports].key?(key.to_sym)
          factory = MODULES[category] or return nil
          return factory.call
        end
        nil
      end

      def report_args(opts)
        # Only forward kwargs that report methods accept; keep the surface tiny.
        opts.slice(:limit).compact
      end

      def severity_counts(key, report)
        thresholds = Dashboard::ReportsRegistry.thresholds(key)
        counts = Hash.new(0)

        if thresholds.empty?
          counts["ok"] = report.size
          return counts
        end

        report.each { |row| counts[row_severity(row, thresholds)] += 1 }
        counts
      end

      def row_severity(row, thresholds)
        worst = "ok"
        thresholds.each do |field, t|
          value = row[field.to_s] || row[field]
          next if value.nil?

          worst = max_severity(worst, severity_for(value.to_f, t))
        end
        worst
      end

      def severity_for(value, thresholds)
        critical = thresholds[:critical]
        warning = thresholds[:warning]

        if thresholds[:inverted]
          return "critical" if critical && value <= critical
          return "warning" if warning && value <= warning
        else
          return "critical" if critical && value >= critical
          return "warning" if warning && value >= warning
        end
        "ok"
      end

      def max_severity(a, b)
        (SEVERITY_ORDER[a] >= SEVERITY_ORDER[b]) ? a : b
      end

      def emit(lines, metric, help)
        buffer = []
        emitter = ->(labels, value) {
          buffer << "#{metric}#{format_labels(labels)} #{value}"
        }
        yield emitter
        return if buffer.empty?

        lines << "# HELP #{metric} #{help}"
        lines << "# TYPE #{metric} gauge"
        lines.concat(buffer)
      end

      def format_labels(labels)
        return "" if labels.nil? || labels.empty?

        pairs = labels.map { |k, v| %(#{k}="#{escape_label(v)}") }
        "{#{pairs.join(",")}}"
      end

      def escape_label(value)
        value.to_s
          .gsub("\\", "\\\\\\\\")
          .gsub('"', '\\"')
          .gsub("\n", '\\n')
      end
    end
  end
end
