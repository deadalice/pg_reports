# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require "active_record"

require_relative "pg_reports/version"
require_relative "pg_reports/error"
require_relative "pg_reports/configuration"
require_relative "pg_reports/sql_loader"
require_relative "pg_reports/executor"
require_relative "pg_reports/report"
require_relative "pg_reports/telegram_sender"
require_relative "pg_reports/annotation_parser"

# Modules
require_relative "pg_reports/modules/queries"
require_relative "pg_reports/modules/indexes"
require_relative "pg_reports/modules/tables"
require_relative "pg_reports/modules/connections"
require_relative "pg_reports/modules/system"

# Dashboard
require_relative "pg_reports/dashboard/reports_registry"

# Rails Engine
require_relative "pg_reports/engine" if defined?(Rails::Engine)

module PgReports
  class << self
    # Query analysis methods
    delegate :slow_queries, :heavy_queries, :expensive_queries,
      :missing_index_queries, :low_cache_hit_queries, :all_queries,
      :reset_statistics!, to: Modules::Queries

    # Index analysis methods
    delegate :unused_indexes, :duplicate_indexes, :invalid_indexes,
      :missing_indexes, :index_usage, :bloated_indexes, :index_sizes,
      to: Modules::Indexes

    # Table analysis methods
    delegate :table_sizes, :bloated_tables, :vacuum_needed,
      :row_counts, :cache_hit_ratios, :seq_scans, :recently_modified,
      to: Modules::Tables

    # Connection analysis methods
    delegate :active_connections, :connection_stats, :long_running_queries,
      :blocking_queries, :locks, :idle_connections,
      :kill_connection, :cancel_query,
      to: Modules::Connections

    # System analysis methods
    delegate :database_sizes, :settings, :extensions,
      :activity_overview, :cache_stats, :pg_stat_statements_available?,
      :pg_stat_statements_preloaded?, :pg_stat_statements_status,
      :enable_pg_stat_statements!,
      to: Modules::System

    # Generate a comprehensive database health report
    # @return [Report] Combined health report
    def health_report
      # Collect all reports
      reports = {
        "Slow Queries" => slow_queries(limit: 10),
        "Expensive Queries" => expensive_queries(limit: 10),
        "Unused Indexes" => unused_indexes(limit: 10),
        "Tables Needing Vacuum" => vacuum_needed(limit: 10),
        "Long Running Queries" => long_running_queries,
        "Blocking Queries" => blocking_queries
      }

      # Build combined data
      combined_data = reports.map do |name, report|
        {
          "section" => name,
          "items_count" => report.size,
          "has_issues" => report.size.positive?
        }
      end

      Report.new(
        title: "Database Health Report",
        data: combined_data,
        columns: %w[section items_count has_issues]
      )
    end

    # Run all reports and send summary to Telegram
    def send_health_report_to_telegram
      health_report.send_to_telegram
    end

    # Shorthand for accessing modules directly
    def queries
      Modules::Queries
    end

    def indexes
      Modules::Indexes
    end

    def tables
      Modules::Tables
    end

    def connections
      Modules::Connections
    end

    def system
      Modules::System
    end
  end
end
