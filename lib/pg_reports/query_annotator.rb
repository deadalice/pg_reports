# frozen_string_literal: true

module PgReports
  # Adds source location comments to SQL queries
  # Similar to Marginalia but focused on file:line information
  #
  # Usage:
  #   # In config/initializers/pg_reports.rb
  #   PgReports::QueryAnnotator.attach! if Rails.env.development?
  #
  module QueryAnnotator
    class << self
      # Attach the annotator to ActiveRecord
      def attach!
        return if @attached

        ActiveSupport.on_load(:active_record) do
          ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(QueryAnnotator::AdapterPatch)
        end

        @attached = true
      end

      # Detach the annotator
      def detach!
        @attached = false
      end

      def attached?
        @attached == true
      end

      # Build annotation comment from caller location
      def build_annotation
        return nil unless PgReports.config.annotate_queries

        location = find_source_location
        return nil unless location

        parts = []
        parts << "file:#{location[:file]}"
        parts << "line:#{location[:line]}"
        parts << "method:#{location[:method]}" if location[:method].present?

        # Add controller/action if available
        if defined?(ActionController::Base) && Thread.current[:pg_reports_controller]
          parts << "controller:#{Thread.current[:pg_reports_controller]}"
          parts << "action:#{Thread.current[:pg_reports_action]}" if Thread.current[:pg_reports_action]
        end

        "/*#{parts.join(",")}*/"
      end

      private

      def find_source_location
        # Skip internal gems and Rails internals
        skip_patterns = [
          %r{/gems/},
          %r{lib/pg_reports},
          %r{lib/ruby},
          %r{active_record},
          %r{active_support},
          %r{action_controller},
          %r{action_view}
        ]

        caller_locations.each do |loc|
          path = loc.path.to_s
          next if skip_patterns.any? { |pattern| path.match?(pattern) }
          next unless path.include?("app/") || path.include?("lib/")

          # Make path relative to Rails root if possible
          relative_path = if defined?(Rails.root) && path.start_with?(Rails.root.to_s)
            path.sub("#{Rails.root}/", "")
          else
            File.basename(path)
          end

          return {
            file: relative_path,
            line: loc.lineno,
            method: loc.label
          }
        end

        nil
      end
    end

    # Patch for ActiveRecord adapter to prepend annotations
    module AdapterPatch
      def execute(sql, name = nil, **kwargs)
        annotated_sql = annotate_sql(sql)
        super(annotated_sql, name, **kwargs)
      end

      def exec_query(sql, name = "SQL", binds = [], **kwargs)
        annotated_sql = annotate_sql(sql)
        super(annotated_sql, name, binds, **kwargs)
      end

      private

      def annotate_sql(sql)
        return sql unless QueryAnnotator.attached?

        annotation = QueryAnnotator.build_annotation
        return sql unless annotation

        # Don't annotate if already annotated
        return sql if sql.include?("/*") && sql.include?("*/")

        # Prepend annotation as comment
        "#{annotation} #{sql}"
      end
    end

    # Controller concern to capture controller/action info
    module ControllerRuntime
      extend ActiveSupport::Concern

      included do
        before_action :set_pg_reports_context
        after_action :clear_pg_reports_context
      end

      private

      def set_pg_reports_context
        Thread.current[:pg_reports_controller] = controller_name
        Thread.current[:pg_reports_action] = action_name
      end

      def clear_pg_reports_context
        Thread.current[:pg_reports_controller] = nil
        Thread.current[:pg_reports_action] = nil
      end
    end
  end
end
