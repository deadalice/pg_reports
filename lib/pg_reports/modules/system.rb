# frozen_string_literal: true

module PgReports
  module Modules
    # System-level database statistics
    # Most report methods are generated from YAML definitions in lib/pg_reports/definitions/system/
    module System
      extend self

      # The following methods are auto-generated from YAML:
      # - database_sizes
      # - settings
      # - extensions
      # - activity_overview
      # - cache_stats

      # pg_stat_statements availability check
      # @return [Boolean] Whether pg_stat_statements is available
      def pg_stat_statements_available?
        result = executor.execute(<<~SQL)
          SELECT EXISTS (
            SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'
          ) AS available
        SQL
        result.first&.fetch("available", false) || false
      end

      # Check if pg_stat_statements is preloaded and functional
      # @return [Boolean] Whether pg_stat_statements is preloaded
      # @note This method tries to query pg_stat_statements directly instead of
      #       checking shared_preload_libraries, which requires pg_read_all_settings role
      def pg_stat_statements_preloaded?
        # If extension is not installed, it can't be preloaded
        return false unless pg_stat_statements_available?

        # Try to query pg_stat_statements - if it works, it's properly preloaded
        executor.execute("SELECT 1 FROM pg_stat_statements LIMIT 1")
        true
      rescue
        false
      end

      # Get pg_stat_statements status details
      # @return [Hash] Status information
      def pg_stat_statements_status
        {
          extension_installed: pg_stat_statements_available?,
          preloaded: pg_stat_statements_preloaded?,
          ready: pg_stat_statements_available? && pg_stat_statements_preloaded?
        }
      end

      # Live metrics for dashboard monitoring
      # @param long_query_threshold [Integer] Threshold in seconds for long queries
      # @return [Hash] Metrics data
      # @raise [StandardError] If no data is returned
      def live_metrics(long_query_threshold: 60)
        data = executor.execute_from_file(:system, :live_metrics,
          long_query_threshold: long_query_threshold)

        row = data.first

        # If no data returned, something is wrong with the query or permissions
        if row.nil? || row.empty?
          raise StandardError, "No statistics data returned. Check database permissions and pg_stat views."
        end

        {
          connections: {
            active: row["active_connections"].to_i,
            idle: row["idle_connections"].to_i,
            total: row["total_connections"].to_i,
            max: row["max_connections"].to_i,
            percent: row["connections_pct"].to_f
          },
          transactions: {
            total: row["total_transactions"].to_i,
            commit: row["xact_commit"].to_i,
            rollback: row["xact_rollback"].to_i
          },
          cache_hit_ratio: row["heap_hit_ratio"].to_f,
          long_running_count: row["long_running_count"].to_i,
          blocked_count: row["blocked_count"].to_i,
          timestamp: row["timestamp_epoch"].to_f
        }
      end

      # Enable pg_stat_statements extension
      # Tries to create extension, returns helpful error if it fails
      # @return [Hash] Result with success status and message
      def enable_pg_stat_statements!
        # Check if already enabled
        if pg_stat_statements_available?
          return {success: true, message: "pg_stat_statements is already enabled"}
        end

        # Try to create extension
        begin
          executor.execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")

          # Verify it worked
          if pg_stat_statements_available? && pg_stat_statements_preloaded?
            {success: true, message: "pg_stat_statements extension created successfully"}
          elsif pg_stat_statements_available?
            {
              success: false,
              message: "Extension created but not preloaded. Add 'pg_stat_statements' to shared_preload_libraries in postgresql.conf and restart PostgreSQL.",
              requires_restart: true
            }
          else
            {
              success: false,
              message: "Failed to create extension. Check database permissions.",
              requires_restart: false
            }
          end
        rescue => e
          error_message = e.message

          # Provide helpful message for common errors
          if error_message.include?("could not open extension control file") ||
              error_message.include?("extension \"pg_stat_statements\" is not available")
            {
              success: false,
              message: "pg_stat_statements is not installed. Add to postgresql.conf: " \
                       "shared_preload_libraries = 'pg_stat_statements' and restart PostgreSQL.",
              requires_restart: true
            }
          else
            {success: false, message: "Failed to create extension: #{error_message}"}
          end
        end
      end

      # Get list of all databases
      # @return [Array<Hash>] List of databases with sizes
      def databases_list
        executor.execute_from_file(:system, :databases_list)
      rescue
        # Fallback to empty array if query fails
        []
      end

      # Get current database name
      # @return [String] Current database name
      def current_database
        result = executor.execute("SELECT current_database() AS database")
        result.first&.fetch("database", "unknown") || "unknown"
      rescue
        "unknown"
      end

      private

      def executor
        @executor ||= Executor.new
      end
    end
  end
end
