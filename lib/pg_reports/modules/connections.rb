# frozen_string_literal: true

module PgReports
  module Modules
    # Connection and lock analysis module
    # Most report methods are generated from YAML definitions in lib/pg_reports/definitions/connections/
    module Connections
      extend self

      # The following methods are auto-generated from YAML:
      # - active_connections
      # - connection_stats
      # - long_running_queries(min_duration_seconds: 60)
      # - blocking_queries
      # - locks
      # - idle_connections

      # Kill a specific backend process
      # @param pid [Integer] Process ID to terminate
      # @return [Boolean] Success status
      def kill_connection(pid)
        result = executor.execute("SELECT pg_terminate_backend(:pid)", pid: pid)
        result.first&.fetch("pg_terminate_backend", false) || false
      end

      # Cancel a specific query (softer than kill)
      # @param pid [Integer] Process ID to cancel
      # @return [Boolean] Success status
      def cancel_query(pid)
        result = executor.execute("SELECT pg_cancel_backend(:pid)", pid: pid)
        result.first&.fetch("pg_cancel_backend", false) || false
      end

      private

      def executor
        @executor ||= Executor.new
      end
    end
  end
end
