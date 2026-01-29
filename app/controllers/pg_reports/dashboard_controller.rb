# frozen_string_literal: true

module PgReports
  class DashboardController < ActionController::Base
    layout "pg_reports/application"

    before_action :authenticate_dashboard!, if: -> { PgReports.config.dashboard_auth.present? }
    before_action :set_categories

    def index
      @pg_stat_status = PgReports.pg_stat_statements_status
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

      render json: {
        success: true,
        title: report.title,
        columns: report.columns,
        data: report.data.first(100),
        total: report.size,
        generated_at: report.generated_at.strftime("%Y-%m-%d %H:%M:%S"),
        thresholds: thresholds,
        problem_fields: problem_fields
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

      # Extract stats from the output
      stats = {}
      if (match = explain_output.match(/Planning Time: ([\d.]+) ms/))
        stats[:planning_time] = match[1].to_f
      end
      if (match = explain_output.match(/Execution Time: ([\d.]+) ms/))
        stats[:execution_time] = match[1].to_f
      end
      if (match = explain_output.match(/cost=[\d.]+\.\.([\d.]+)/))
        stats[:total_cost] = match[1].to_f
      end
      if (match = explain_output.match(/rows=(\d+)/))
        stats[:rows] = match[1].to_i
      end

      render json: {success: true, explain: explain_output, stats: stats}
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
      unless normalized.start_with?("select") || normalized.start_with?("show")
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
        if key.to_s.end_with?('_threshold') && value.present?
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
      params_hash.keys.map(&:to_i).sort.reverse.each do |num|
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

      # Check if it looks like a number
      if str.match?(/\A-?\d+(\.\d+)?\z/)
        str
      # Check if it looks like a boolean
      elsif str.downcase.in?(["true", "false"])
        str.downcase
      # Check if it looks like NULL
      elsif str.downcase == "null"
        "NULL"
      else
        # Quote as string, escape single quotes
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
  end
end
