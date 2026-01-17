# frozen_string_literal: true

module PgReports
  module Modules
    # System-level database statistics
    module System
      extend self

      # Database sizes
      # @return [Report] Report with database sizes
      def database_sizes
        data = executor.execute_from_file(:system, :database_sizes)

        Report.new(
          title: "Database Sizes",
          data: data,
          columns: %w[database size_mb size_pretty]
        )
      end

      # PostgreSQL settings
      # @return [Report] Report with important PostgreSQL settings
      def settings
        data = executor.execute_from_file(:system, :settings)

        Report.new(
          title: "PostgreSQL Settings",
          data: data,
          columns: %w[name setting unit category description]
        )
      end

      # Extension information
      # @return [Report] Report with installed extensions
      def extensions
        data = executor.execute_from_file(:system, :extensions)

        Report.new(
          title: "Installed Extensions",
          data: data,
          columns: %w[name version schema description]
        )
      end

      # Database activity overview
      # @return [Report] Report with current activity
      def activity_overview
        data = executor.execute_from_file(:system, :activity_overview)

        Report.new(
          title: "Database Activity Overview",
          data: data,
          columns: %w[metric value]
        )
      end

      # Cache hit ratio for the entire database
      # @return [Report] Report with cache statistics
      def cache_stats
        data = executor.execute_from_file(:system, :cache_stats)

        Report.new(
          title: "Database Cache Statistics",
          data: data,
          columns: %w[database heap_hit_ratio index_hit_ratio]
        )
      end

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

      # Check if pg_stat_statements is in shared_preload_libraries
      # @return [Boolean] Whether pg_stat_statements is preloaded
      def pg_stat_statements_preloaded?
        result = executor.execute(<<~SQL)
          SELECT setting FROM pg_settings WHERE name = 'shared_preload_libraries'
        SQL
        setting = result.first&.fetch("setting", "") || ""
        setting.include?("pg_stat_statements")
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
          if pg_stat_statements_available?
            {success: true, message: "pg_stat_statements extension created successfully"}
          else
            {
              success: false,
              message: "Extension created but not working. Check shared_preload_libraries in postgresql.conf",
              requires_restart: true
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

      private

      def executor
        @executor ||= Executor.new
      end
    end
  end
end
