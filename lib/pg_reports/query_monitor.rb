# frozen_string_literal: true

require "singleton"
require "securerandom"
require "json"

module PgReports
  class QueryMonitor
    include Singleton

    attr_reader :enabled, :session_id

    def initialize
      @enabled = false
      @subscriber = nil
      @mutex = Mutex.new
      @session_id = nil
      @queries = []
    end

    def start
      @mutex.synchronize do
        if @enabled
          return {success: false, message: "Monitoring already active"}
        end

        @session_id = SecureRandom.uuid
        @queries = []
        @enabled = true

        # Subscribe to sql.active_record events
        @subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |name, started, finished, unique_id, payload|
          handle_sql_event(name, started, finished, unique_id, payload)
        end

        # Write session start marker to file
        write_session_marker("session_start")

        {success: true, message: "Query monitoring started", session_id: @session_id}
      end
    rescue => e
      @enabled = false
      {success: false, error: e.message}
    end

    def stop
      @mutex.synchronize do
        unless @enabled
          return {success: false, message: "Monitoring not active"}
        end

        # Unsubscribe from notifications
        if @subscriber
          ActiveSupport::Notifications.unsubscribe(@subscriber)
          @subscriber = nil
        end

        # Write session end marker to file
        write_session_marker("session_end")

        # Flush queries to file
        flush_to_file

        @enabled = false
        @queries = []
        session_id = @session_id
        @session_id = nil

        {success: true, message: "Query monitoring stopped", session_id: session_id}
      end
    rescue => e
      {success: false, error: e.message}
    end

    def status
      {
        enabled: @enabled,
        session_id: @session_id,
        query_count: @queries.size
      }
    end

    def queries(limit: nil, session_id: nil)
      result = @queries.dup

      # Filter by session_id if provided
      if session_id
        result = result.select { |q| q[:session_id] == session_id }
      end

      # Limit results if requested
      if limit
        result = result.last(limit)
      end

      result
    end

    def load_from_log(session_id: nil, limit: nil)
      return [] unless log_file_enabled?
      return [] unless File.exist?(log_file_path)

      queries = []

      begin
        File.open(log_file_path, "r") do |f|
          f.each_line do |line|
            entry = JSON.parse(line.strip, symbolize_names: true)
            next unless entry[:type] == "query"

            # Filter by session_id if provided
            next if session_id && entry[:session_id] != session_id

            queries << entry
          rescue JSON::ParserError
            # Skip malformed lines
            next
          end
        end

        # Limit results if requested
        queries = queries.last(limit) if limit

        queries
      rescue => e
        Rails.logger.warn("PgReports: Failed to load queries from log: #{e.message}")
        []
      end
    end

    private

    def handle_sql_event(name, started, finished, unique_id, payload)
      return unless @enabled

      # Skip if should be filtered
      return if should_skip?(payload)

      duration_ms = ((finished - started) * 1000).round(2)
      sql = payload[:sql]
      query_name = payload[:name]

      # Extract source location
      source_location = extract_source_location

      # Build query entry
      query_entry = {
        type: "query",
        session_id: @session_id,
        sql: sql,
        duration_ms: duration_ms,
        name: query_name,
        source_location: source_location,
        timestamp: Time.current.iso8601
      }

      add_to_buffer(query_entry)
    end

    def should_skip?(payload)
      sql = payload[:sql]
      name = payload[:name]

      # Skip if query is from pg_reports itself (check by name)
      return true if name&.start_with?("PgReports")

      # Skip if query is from pg_reports gem (check backtrace)
      # if query_from_pg_reports?
      #  return true
      # end

      # Skip SCHEMA queries
      return true if name&.start_with?("SCHEMA")

      # Skip CACHE queries
      return true if name == "CACHE"

      # Skip if cached
      return true if payload[:cached]

      # Skip EXPLAIN queries
      return true if sql&.match?(/\bEXPLAIN\b/i)

      # Skip DDL statements
      return true if sql&.match?(/\b(CREATE|ALTER|DROP)\b/i)

      false
    end

    def query_from_pg_reports?
      # Check if query originates from pg_reports gem code (not tests)
      locations = caller_locations(0, 30)
      return false unless locations

      locations.any? do |location|
        path = location.path
        # Match gem paths: /gems/pg_reports-X.Y.Z/lib/ or local /lib/pg_reports/
        # But exclude test paths: /spec/
        next if path.include?("/spec/")

        # Match both gem installation and local development lib paths
        path.match?(%r{/gems/pg_reports[-\d.]+/lib/}) ||
          path.match?(%r{/lib/pg_reports/})
      end
    end

    def extract_source_location
      filter_proc = PgReports.config.query_monitor_backtrace_filter

      # Get caller locations, skip first few frames (this file, active_support)
      locations = caller_locations(5, 20)

      return nil unless locations

      # Find first application code location
      app_location = locations.find do |location|
        filter_proc.call(location)
      end

      return nil unless app_location

      {
        file: app_location.path,
        line: app_location.lineno,
        method: app_location.label
      }
    rescue
      # If source extraction fails, return nil
      nil
    end

    def add_to_buffer(query_entry)
      @queries << query_entry

      # Trim to max_queries to prevent memory bloat
      max_queries = PgReports.config.query_monitor_max_queries
      if @queries.size > max_queries
        @queries = @queries.last(max_queries)
      end
    end

    def write_session_marker(marker_type)
      return unless log_file_enabled?

      marker = {
        type: marker_type,
        session_id: @session_id,
        timestamp: Time.current.iso8601
      }

      File.open(log_file_path, "a") do |f|
        f.puts marker.to_json
      end
    rescue => e
      # Silently fail - don't break monitoring if file write fails
      Rails.logger.warn("PgReports: Failed to write session marker: #{e.message}")
    end

    def flush_to_file
      return unless log_file_enabled?
      return if @queries.empty?

      File.open(log_file_path, "a") do |f|
        @queries.each do |query|
          f.puts query.to_json
        end
      end
    rescue => e
      Rails.logger.warn("PgReports: Failed to flush queries to file: #{e.message}")
    end

    def log_file_enabled?
      PgReports.config.query_monitor_log_file.present?
    end

    def log_file_path
      PgReports.config.query_monitor_log_file
    end
  end
end
