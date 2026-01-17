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

    def show
      @category = params[:category].to_sym
      @report_key = params[:report].to_sym
      @report_info = Dashboard::ReportsRegistry.find(@category, @report_key)

      if @report_info.nil?
        redirect_to root_path, alert: "Report not found"
        return
      end

      @report = execute_report(@category, @report_key)
    rescue => e
      @error = e.message
      @report = nil
    end

    def run
      category = params[:category].to_sym
      report_key = params[:report].to_sym

      report = execute_report(category, report_key)

      render json: {
        success: true,
        title: report.title,
        columns: report.columns,
        data: report.data.first(100),
        total: report.size,
        generated_at: report.generated_at.strftime("%Y-%m-%d %H:%M:%S")
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
