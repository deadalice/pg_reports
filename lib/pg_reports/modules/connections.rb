# frozen_string_literal: true

module PgReports
  module Modules
    # Connection and lock analysis module
    module Connections
      extend self

      # Active connections
      # @return [Report] Report with active connections
      def active_connections
        data = executor.execute_from_file(:connections, :active_connections)

        Report.new(
          title: "Active Connections",
          data: data,
          columns: %w[pid database username application state query_start state_change query]
        )
      end

      # Connection statistics by state
      # @return [Report] Report with connection counts by state
      def connection_stats
        data = executor.execute_from_file(:connections, :connection_stats)

        Report.new(
          title: "Connection Statistics",
          data: data,
          columns: %w[database state count]
        )
      end

      # Long running queries
      # @return [Report] Report with long running queries
      def long_running_queries(min_duration_seconds: 60)
        data = executor.execute_from_file(:connections, :long_running_queries)

        filtered = data.select { |row| row["duration_seconds"].to_f >= min_duration_seconds }

        Report.new(
          title: "Long Running Queries (>= #{min_duration_seconds}s)",
          data: filtered,
          columns: %w[pid database username duration_seconds state query]
        )
      end

      # Blocking queries - queries that are blocking others
      # @return [Report] Report with blocking queries
      def blocking_queries
        data = executor.execute_from_file(:connections, :blocking_queries)

        Report.new(
          title: "Blocking Queries",
          data: data,
          columns: %w[blocked_pid blocking_pid blocked_query blocking_query blocked_duration]
        )
      end

      # Lock statistics
      # @return [Report] Report with lock statistics
      def locks
        data = executor.execute_from_file(:connections, :locks)

        Report.new(
          title: "Current Locks",
          data: data,
          columns: %w[pid database relation locktype mode granted waiting]
        )
      end

      # Idle connections
      # @return [Report] Report with idle connections
      def idle_connections
        data = executor.execute_from_file(:connections, :idle_connections)

        Report.new(
          title: "Idle Connections",
          data: data,
          columns: %w[pid database username application idle_duration state_change]
        )
      end

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
