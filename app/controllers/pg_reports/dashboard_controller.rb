# frozen_string_literal: true

module PgReports
  class DashboardController < ActionController::Base
    layout "pg_reports/application"

    before_action :authenticate_dashboard!, if: -> { PgReports.config.dashboard_auth.present? }
    before_action :set_categories

    def index
      @pg_stat_status = PgReports.pg_stat_statements_status
      @current_database = PgReports.system.current_database
    end

    def enable_pg_stat_statements
      result = PgReports.enable_pg_stat_statements!
      render json: result
    end

    def reset_statistics
      PgReports.reset_statistics!
      render json: {success: true, message: "Statistics have been reset successfully"}
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def live_metrics
      threshold = params[:long_query_threshold]&.to_i || 60
      data = Modules::System.live_metrics(long_query_threshold: threshold)

      render json: {
        success: true,
        metrics: data,
        timestamp: Time.current.to_i
      }
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def show
      @category = params[:category].to_sym
      @report_key = params[:report].to_sym
      @report_info = Dashboard::ReportsRegistry.find(@category, @report_key)

      if @report_info.nil?
        redirect_to root_path, alert: "Report not found"
        return
      end

      # Get documentation for the report
      @documentation = Dashboard::ReportsRegistry.documentation(@report_key)
      @thresholds = Dashboard::ReportsRegistry.thresholds(@report_key)
      @problem_fields = Dashboard::ReportsRegistry.problem_fields(@report_key)

      # Load filter parameters from YAML
      @report_filters = load_report_filters(@category, @report_key)

      @report = execute_report(@category, @report_key)
    rescue => e
      @error = e.message
      @report = nil
    end

    def run
      category = params[:category].to_sym
      report_key = params[:report].to_sym

      # Extract filter parameters from request
      filter_params = extract_filter_params

      report = execute_report(category, report_key, **filter_params)
      thresholds = Dashboard::ReportsRegistry.thresholds(report_key)
      problem_fields = Dashboard::ReportsRegistry.problem_fields(report_key)
      problem_explanations = load_problem_explanations(category, report_key)

      render json: {
        success: true,
        title: report.title,
        columns: report.columns,
        data: report.data.first(100),
        total: report.size,
        generated_at: report.generated_at.strftime("%Y-%m-%d %H:%M:%S"),
        thresholds: thresholds,
        problem_fields: problem_fields,
        problem_explanations: problem_explanations
      }
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def send_to_telegram
      category = params[:category].to_sym
      report_key = params[:report].to_sym

      report = execute_report(category, report_key)

      if report.size > 50
        report.send_to_telegram_as_file
      else
        report.send_to_telegram
      end

      render json: {success: true, message: "Report sent to Telegram"}
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def download
      category = params[:category].to_sym
      report_key = params[:report].to_sym
      format_type = params[:format] || "txt"

      report = execute_report(category, report_key)
      filename = "#{report.title.parameterize}-#{Time.current.strftime("%Y%m%d-%H%M%S")}"

      case format_type
      when "csv"
        send_data report.to_csv,
          filename: "#{filename}.csv",
          type: "text/csv; charset=utf-8",
          disposition: "attachment"
      when "json"
        send_data report.to_a.to_json,
          filename: "#{filename}.json",
          type: "application/json; charset=utf-8",
          disposition: "attachment"
      else
        send_data report.to_text,
          filename: "#{filename}.txt",
          type: "text/plain; charset=utf-8",
          disposition: "attachment"
      end
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def explain_analyze
      query = params[:query]
      query_params = params[:params] || {}

      if query.blank?
        render json: {success: false, error: "Query is required"}, status: :unprocessable_entity
        return
      end

      # Security: Only allow SELECT queries for EXPLAIN ANALYZE (SHOW not supported by EXPLAIN)
      normalized = query.strip.gsub(/\s+/, " ").downcase
      unless normalized.start_with?("select")
        render json: {success: false, error: "Only SELECT queries are allowed for EXPLAIN ANALYZE"}, status: :unprocessable_entity
        return
      end

      # Substitute parameters if provided
      final_query = substitute_params(query, query_params)

      # Check for remaining unsubstituted parameters
      if final_query.match?(/\$\d+/)
        render json: {
          success: false,
          error: "Please provide values for all parameter placeholders ($1, $2, etc.)"
        }, status: :unprocessable_entity
        return
      end

      result = ActiveRecord::Base.connection.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) #{final_query}")
      explain_output = result.map { |r| r["QUERY PLAN"] }.join("\n")

      # Analyze the EXPLAIN output
      analyzer = ExplainAnalyzer.new(explain_output)
      analysis = analyzer.to_h

      render json: {
        success: true,
        explain: explain_output,
        stats: analysis[:stats],
        annotated_lines: analysis[:annotated_lines],
        problems: analysis[:problems],
        summary: analysis[:summary]
      }
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def execute_query
      query = params[:query]
      query_params = params[:params] || {}

      if query.blank?
        render json: {success: false, error: "Query is required"}, status: :unprocessable_entity
        return
      end

      # Security: Only allow SELECT and SHOW queries
      normalized = query.strip.gsub(/\s+/, " ").downcase
      unless normalized.start_with?("select", "show")
        render json: {success: false, error: "Only SELECT and SHOW queries are allowed"}, status: :unprocessable_entity
        return
      end

      # Substitute parameters if provided
      final_query = substitute_params(query, query_params)

      # Check for remaining unsubstituted parameters
      if final_query.match?(/\$\d+/)
        render json: {
          success: false,
          error: "Please provide values for all parameter placeholders ($1, $2, etc.)"
        }, status: :unprocessable_entity
        return
      end

      # Execute with LIMIT to prevent huge result sets
      limited_query = add_limit_if_missing(final_query, 100)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = ActiveRecord::Base.connection.execute(limited_query)
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      execution_time = ((end_time - start_time) * 1000).round(2)

      rows = result.to_a
      columns = rows.first&.keys || []

      # Check if we need to get total count
      total_count = rows.size
      truncated = false

      if rows.size >= 100
        # Check if there are more rows
        count_result = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM (#{final_query}) AS count_query")
        total_count = count_result.first["count"].to_i
        truncated = total_count > 100
      end

      render json: {
        success: true,
        columns: columns,
        rows: rows,
        count: rows.size,
        total_count: total_count,
        truncated: truncated,
        execution_time: execution_time
      }
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def create_migration
      # Only allow migration creation in development environment
      unless Rails.env.development?
        render json: {
          success: false,
          error: "Migration creation is only allowed in development environment"
        }, status: :forbidden
        return
      end

      file_name = params[:file_name]
      code = params[:code]

      if file_name.blank? || code.blank?
        render json: {success: false, error: "File name and code are required"}, status: :unprocessable_entity
        return
      end

      # Sanitize file name
      safe_file_name = file_name.gsub(/[^a-z0-9_.]/, "")
      unless safe_file_name.match?(/\A\d{14}_\w+\.rb\z/)
        render json: {success: false, error: "Invalid migration file name format"}, status: :unprocessable_entity
        return
      end

      # Find migrations directory
      migrations_path = Rails.root.join("db", "migrate")
      unless migrations_path.exist?
        render json: {success: false, error: "Migrations directory not found"}, status: :unprocessable_entity
        return
      end

      file_path = migrations_path.join(safe_file_name)
      File.write(file_path, code)

      render json: {success: true, file_path: file_path.to_s, message: "Migration created successfully"}
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def start_query_monitoring
      monitor = QueryMonitor.instance

      result = monitor.start

      if result[:success]
        render json: result
      else
        render json: result, status: :unprocessable_entity
      end
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def stop_query_monitoring
      monitor = QueryMonitor.instance

      result = monitor.stop

      if result[:success]
        render json: result
      else
        render json: result, status: :unprocessable_entity
      end
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def query_monitor_status
      monitor = QueryMonitor.instance
      status = monitor.status

      render json: {
        success: true,
        enabled: status[:enabled],
        session_id: status[:session_id],
        query_count: status[:query_count]
      }
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def query_monitor_feed
      monitor = QueryMonitor.instance

      unless monitor.enabled
        render json: {success: false, message: "Monitoring not active"}
        return
      end

      limit = params[:limit]&.to_i || 50
      session_id = params[:session_id]

      queries = monitor.queries(limit: limit, session_id: session_id)

      render json: {
        success: true,
        queries: queries,
        timestamp: Time.current.to_i
      }
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def load_query_history
      monitor = QueryMonitor.instance

      limit = params[:limit]&.to_i || 100
      session_id = params[:session_id]

      queries = monitor.load_from_log(limit: limit, session_id: session_id)

      render json: {
        success: true,
        queries: queries,
        timestamp: Time.current.to_i
      }
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    def download_query_monitor
      monitor = QueryMonitor.instance

      # Allow download even when monitoring is stopped, as long as there are queries
      queries = monitor.queries
      if queries.empty?
        render json: {success: false, error: "No queries to download"}, status: :unprocessable_entity
        return
      end

      format_type = params[:format] || "txt"
      filename = "query-monitor-#{Time.current.strftime("%Y%m%d-%H%M%S")}"

      case format_type
      when "csv"
        csv_data = generate_query_monitor_csv(queries)
        send_data csv_data,
          filename: "#{filename}.csv",
          type: "text/csv; charset=utf-8",
          disposition: "attachment"
      when "json"
        send_data queries.to_json,
          filename: "#{filename}.json",
          type: "application/json; charset=utf-8",
          disposition: "attachment"
      else
        text_data = generate_query_monitor_text(queries)
        send_data text_data,
          filename: "#{filename}.txt",
          type: "text/plain; charset=utf-8",
          disposition: "attachment"
      end
    rescue => e
      render json: {success: false, error: e.message}, status: :unprocessable_entity
    end

    private

    def authenticate_dashboard!
      instance_exec(&PgReports.config.dashboard_auth)
    end

    def set_categories
      @categories = Dashboard::ReportsRegistry.all
    end

    def load_report_filters(category, report_key)
      definition = ReportLoader.get(category.to_s, report_key.to_s)
      return {} unless definition

      definition.filter_parameters
    end

    def load_problem_explanations(category, report_key)
      definition = ReportLoader.get(category.to_s, report_key.to_s)
      return {} unless definition

      definition.problem_explanations
    end

    def extract_filter_params
      # Allow common filter parameters
      allowed = [:limit, :min_duration_seconds, :min_calls]
      result = {}

      allowed.each do |key|
        if params[key].present?
          value = params[key].to_s
          # Convert to appropriate type
          result[key] = value.match?(/^\d+$/) ? value.to_i : value
        end
      end

      # Also allow threshold overrides (calls_threshold, etc.)
      params.each do |key, value|
        if key.to_s.end_with?("_threshold") && value.present?
          result[key.to_sym] = value.to_i
        end
      end

      result
    end

    def execute_report(category, report_key, **filter_params)
      mod = case category
      when :queries then Modules::Queries
      when :indexes then Modules::Indexes
      when :tables then Modules::Tables
      when :connections then Modules::Connections
      when :system then Modules::System
      when :schema_analysis then Modules::SchemaAnalysis
      else raise ArgumentError, "Unknown category: #{category}"
      end

      unless mod.respond_to?(report_key)
        raise ArgumentError, "Unknown report: #{report_key}"
      end

      mod.public_send(report_key, **filter_params)
    end

    def substitute_params(query, params_hash)
      result = query.dup

      # Sort by param number descending to replace $10 before $1
      params_hash.keys.map(&:to_i).sort.reverse_each do |num|
        value = params_hash[num.to_s] || params_hash[num]
        next if value.nil? || value.to_s.empty?

        # Quote the value appropriately
        quoted_value = quote_param_value(value)
        result = result.gsub("$#{num}", quoted_value)
      end

      result
    end

    def quote_param_value(value)
      str = value.to_s

      # Check if it looks like NULL
      if str.downcase == "null"
        "NULL"
      # Check if it looks like a boolean
      elsif str.downcase.in?(["true", "false"])
        str.downcase
      else
        # Quote as string by default - PostgreSQL will handle type casting
        # This ensures compatibility with both text and numeric columns
        "'#{str.gsub("'", "''")}'"
      end
    end

    def add_limit_if_missing(query, limit)
      # Simple check - if query doesn't end with LIMIT clause, add one
      normalized = query.strip.gsub(/\s+/, " ").downcase

      if normalized.match?(/\blimit\s+\d+\s*(?:offset\s+\d+\s*)?\z/i)
        # Already has LIMIT
        query
      else
        "#{query} LIMIT #{limit}"
      end
    end

    def generate_query_monitor_csv(queries)
      require "csv"

      CSV.generate do |csv|
        # Header
        csv << ["Timestamp", "Duration (ms)", "Query Name", "SQL", "Source File", "Source Line"]

        # Data rows
        queries.each do |query|
          csv << [
            query[:timestamp],
            query[:duration_ms],
            query[:name],
            query[:sql],
            query.dig(:source_location, :file),
            query.dig(:source_location, :line)
          ]
        end
      end
    end

    def generate_query_monitor_text(queries)
      output = []
      output << "=" * 80
      output << "Query Monitor Export"
      output << "Generated: #{Time.current.strftime("%Y-%m-%d %H:%M:%S")}"
      output << "Total Queries: #{queries.size}"
      output << "=" * 80
      output << ""

      queries.each_with_index do |query, index|
        output << "Query ##{index + 1}"
        output << "-" * 80
        output << "Timestamp:  #{query[:timestamp]}"
        output << "Duration:   #{query[:duration_ms]}ms"
        output << "Name:       #{query[:name]}"

        if query[:source_location]
          output << "Source:     #{query[:source_location][:file]}:#{query[:source_location][:line]}"
        end

        output << ""
        output << "SQL:"
        output << query[:sql]
        output << ""
        output << ""
      end

      output.join("\n")
    end
  end
end
