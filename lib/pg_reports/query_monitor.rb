# frozen_string_literal: true

require "singleton"
require "securerandom"
require "json"

module PgReports
  class QueryMonitor
    include Singleton

    CACHE_KEY_ENABLED = "pg_reports:query_monitor:enabled"
    CACHE_KEY_SESSION_ID = "pg_reports:query_monitor:session_id"
    CACHE_TTL = 24.hours

    def initialize
      @subscriber = nil
      @mutex = Mutex.new
      @queries = []
      ensure_subscription_if_enabled
    end

    def enabled
      cache_read(CACHE_KEY_ENABLED) || false
    end

    def session_id
      cache_read(CACHE_KEY_SESSION_ID)
    end

    def start
      @mutex.synchronize do
        if enabled
          Rails.logger.info("PgReports: Monitoring already active, session_id=#{session_id}") if defined?(Rails)
          return {success: false, message: "Monitoring already active"}
        end

        new_session_id = SecureRandom.uuid
        @queries = []

        # Store state in cache so all processes can see it
        cache_write(CACHE_KEY_ENABLED, true)
        cache_write(CACHE_KEY_SESSION_ID, new_session_id)

        Rails.logger.info("PgReports: Monitoring started, session_id=#{new_session_id}") if defined?(Rails)

        # Subscribe to sql.active_record events in THIS process
        ensure_subscription

        # Write session start marker to file
        write_session_marker("session_start")

        {success: true, message: "Query monitoring started", session_id: new_session_id}
      end
    rescue => e
      cache_write(CACHE_KEY_ENABLED, false)
      {success: false, error: e.message}
    end

    def stop
      @mutex.synchronize do
        unless enabled
          return {success: false, message: "Monitoring not active"}
        end

        current_session_id = session_id

        # Unsubscribe from notifications in THIS process
        if @subscriber
          ActiveSupport::Notifications.unsubscribe(@subscriber)
          @subscriber = nil
        end

        # Write session end marker to file
        write_session_marker("session_end")

        # Flush queries to file
        flush_to_file

        # Clear state from cache
        cache_delete(CACHE_KEY_ENABLED)
        cache_delete(CACHE_KEY_SESSION_ID)

        @queries = []

        {success: true, message: "Query monitoring stopped", session_id: current_session_id}
      end
    rescue => e
      {success: false, error: e.message}
    end

    def status
      {
        enabled: enabled,
        session_id: session_id,
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
        Rails.logger.warn("PgReports: Failed to load queries from log: #{e.message}") if defined?(Rails)
        []
      end
    end

    private

    # Cache helpers - work with or without Rails.cache
    def cache_read(key)
      return nil unless cache_available?
      Rails.cache.read(key)
    rescue => e
      Rails.logger.warn("PgReports: Cache read failed: #{e.message}") if defined?(Rails.logger)
      nil
    end

    def cache_write(key, value)
      return false unless cache_available?
      Rails.cache.write(key, value, expires_in: CACHE_TTL)
    rescue => e
      Rails.logger.warn("PgReports: Cache write failed: #{e.message}") if defined?(Rails.logger)
      false
    end

    def cache_delete(key)
      return false unless cache_available?
      Rails.cache.delete(key)
    rescue => e
      Rails.logger.warn("PgReports: Cache delete failed: #{e.message}") if defined?(Rails.logger)
      false
    end

    def cache_available?
      defined?(Rails) && defined?(Rails.cache)
    end

    # Ensure this process is subscribed to notifications if monitoring is enabled
    def ensure_subscription_if_enabled
      return unless enabled
      ensure_subscription
    end

    def ensure_subscription
      return if @subscriber # Already subscribed

      @subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |name, started, finished, unique_id, payload|
        handle_sql_event(name, started, finished, unique_id, payload)
      end

      Rails.logger.debug("PgReports: Subscribed to sql.active_record in process #{Process.pid}") if defined?(Rails.logger)
    end

    def handle_sql_event(name, started, finished, unique_id, payload)
      return unless enabled

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
        session_id: session_id,
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
      if query_from_pg_reports?
        return true
      end

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
      # Check if query originates from pg_reports gem internal code
      locations = caller_locations(0, 30)
      return false unless locations

      locations.any? do |location|
        path = location.path
        # Exclude test paths
        next if path.include?("/spec/")

        # IMPORTANT: Exclude query_monitor.rb itself to prevent false positives
        # when gem is installed from RubyGems
        next if path.include?("/query_monitor.rb")

        # Filter queries from pg_reports internal modules only:
        # - Installed gem: /gems/pg_reports-X.Y.Z/lib/
        # - Local gem: /pg_reports/lib/pg_reports/modules/
        # Note: We intentionally DO NOT filter dashboard_controller.rb
        # to allow monitoring of user application queries made during dashboard page loads
        path.match?(%r{/gems/pg_reports[-\d.]+/lib/}) ||
          path.match?(%r{/pg_reports/lib/pg_reports/modules/})
      end
    end

    def extract_source_location
      # Get caller locations, skip first few frames (this file, active_support)
      # Increase limit to 50 to capture more of the stack
      locations = caller_locations(5, 50)

      return nil unless locations

      # Find first application code location
      # Look for paths that are NOT from gems/ruby/railties
      app_location = locations.find do |location|
        path = location.path

        # Skip framework and gem paths
        next if path.match?(%r{/(gems|ruby|railties)/})

        # Skip pg_reports internal paths
        next if path.match?(%r{/pg_reports/lib/pg_reports/})
        next if path.match?(%r{/pg_reports/app/controllers/pg_reports/})

        # This is likely application code
        true
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
        session_id: session_id,
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
