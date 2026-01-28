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

      @report = execute_report(@category, @report_key)
    rescue => e
      @error = e.message
      @report = nil
    end

    def run
      category = params[:category].to_sym
      report_key = params[:report].to_sym

      report = execute_report(category, report_key)
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

      if query.blank?
        render json: {success: false, error: "Query is required"}, status: :unprocessable_entity
        return
      end

      # Security: Only allow SELECT queries for EXPLAIN ANALYZE
      normalized = query.strip.gsub(/\s+/, " ").downcase
      unless normalized.start_with?("select")
        render json: {success: false, error: "Only SELECT queries are allowed for EXPLAIN ANALYZE"}, status: :unprocessable_entity
        return
      end

      # Check for parameterized queries (from pg_stat_statements normalization)
      if query.match?(/\$\d+/)
        render json: {
          success: false,
          error: "This query contains parameter placeholders ($1, $2, etc.) from pg_stat_statements normalization. " \
                 "EXPLAIN ANALYZE cannot be run on parameterized queries without actual values. " \
                 "Copy the query and replace parameters with real values to analyze it manually."
        }, status: :unprocessable_entity
        return
      end

      result = ActiveRecord::Base.connection.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) #{query}")
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

    def create_migration
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

    def execute_report(category, report_key)
      mod = case category
      when :queries then Modules::Queries
      when :indexes then Modules::Indexes
      when :tables then Modules::Tables
      when :connections then Modules::Connections
      when :system then Modules::System
      else raise ArgumentError, "Unknown category: #{category}"
      end

      unless mod.respond_to?(report_key)
        raise ArgumentError, "Unknown report: #{report_key}"
      end

      mod.public_send(report_key)
    end
  end
end
