# frozen_string_literal: true

require "active_support"
require "active_support/core_ext"
require "active_record"

require_relative "pg_reports/version"
require_relative "pg_reports/error"
require_relative "pg_reports/connection/target"
require_relative "pg_reports/connection/registry"
require_relative "pg_reports/connection/error_translator"
require_relative "pg_reports/compatibility"
require_relative "pg_reports/configuration"
require_relative "pg_reports/sql_loader"
require_relative "pg_reports/executor"
require_relative "pg_reports/report"
require_relative "pg_reports/telegram_sender"
require_relative "pg_reports/annotation_parser"
require_relative "pg_reports/explain_analyzer"
require_relative "pg_reports/query_monitor"

# YAML-based report system
require_relative "pg_reports/filter"
require_relative "pg_reports/report_definition"
require_relative "pg_reports/report_loader"
require_relative "pg_reports/module_generator"

# Modules
require_relative "pg_reports/modules/queries"
require_relative "pg_reports/modules/indexes"
require_relative "pg_reports/modules/tables"
require_relative "pg_reports/modules/connections"
require_relative "pg_reports/modules/system"
require_relative "pg_reports/modules/schema_analysis"

# Dashboard
require_relative "pg_reports/dashboard/reports_registry"

# Grafana / Prometheus exporter
require_relative "pg_reports/grafana/exporter"
require_relative "pg_reports/grafana/dashboard_builder"

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

    # Schema analysis methods
    delegate :missing_validations,
      to: Modules::SchemaAnalysis

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

    def schema_analysis
      Modules::SchemaAnalysis
    end

    # Reload YAML report definitions and regenerate module methods
    def reload_definitions!
      ReportLoader.reload!
      ModuleGenerator.generate!
    end

    # Connection registry — multi-target / multi-database support.
    # The :primary target is auto-discovered from ActiveRecord on first access.
    def connection_registry
      @connection_registry ||= Connection::Registry.new
    end

    # Run a block against a specific target (and optionally a specific database
    # on that target). Honored by Executor and any code routing through
    # PgReports.config.connection.
    #
    #   PgReports.with_target(:analytics) { PgReports.slow_queries }
    #   PgReports.with_target(:primary, database: "logs") { PgReports.table_sizes }
    def with_target(name, database: nil, &block)
      connection_registry.with_context(target: name, database: database, &block)
    end

    # Switch only the database on whatever target is currently active
    # (defaults to the registry's default target).
    #
    #   PgReports.with_database("reporting") { PgReports.database_sizes }
    def with_database(database, &block)
      target = connection_registry.current_name || connection_registry.default_name
      connection_registry.with_context(target: target, database: database, &block)
    end

    # Name of the currently effective target (taking with_target into account).
    def current_target_name
      connection_registry.current_name || connection_registry.default_name
    end

    # Name of the currently effective database (taking with_database into account).
    def current_database_name
      connection_registry.current_database_name
    end

    # List databases on the currently active target's cluster.
    # Each row: { "name" => String, "size" => String, "current" => Boolean }
    def list_databases
      target = connection_registry.fetch
      target.list_databases(current: current_database_name)
    end

    # List of registered targets, each as { name:, default_database:, current: }.
    def list_targets
      current = current_target_name
      connection_registry.targets.map do |t|
        {name: t.name, default_database: t.default_database, current: t.name == current}
      end
    end
  end
end

# Generate YAML-based methods on load
PgReports::ModuleGenerator.generate!

# Check Ruby and Rails versions immediately (no DB needed)
PgReports::Compatibility.check_ruby!
PgReports::Compatibility.check_rails!
