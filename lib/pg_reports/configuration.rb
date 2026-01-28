# frozen_string_literal: true

module PgReports
  class Configuration
    # Telegram settings
    attr_accessor :telegram_bot_token
    attr_accessor :telegram_chat_id

    # Query analysis thresholds
    attr_accessor :slow_query_threshold_ms      # Queries slower than this are considered slow
    attr_accessor :heavy_query_threshold_calls  # Queries with more calls than this are heavy
    attr_accessor :expensive_query_threshold_ms # Total time threshold for expensive queries

    # Index analysis thresholds
    attr_accessor :unused_index_threshold_scans # Index with fewer scans is unused

    # Table analysis thresholds
    attr_accessor :bloat_threshold_percent      # Tables with more bloat are problematic
    attr_accessor :dead_rows_threshold          # Tables with more dead rows need vacuum

    # Connection settings
    attr_accessor :connection_pool              # Custom connection pool (optional)

    # Output settings
    attr_accessor :max_query_length             # Truncate query text to this length

    # Dashboard settings
    attr_accessor :dashboard_auth               # Proc for dashboard authentication

    # Assets / privacy settings
    attr_accessor :load_external_fonts          # When true, loads Google Fonts in the dashboard layout

    # Development/testing settings
    attr_accessor :fake_source_data             # Inject fake source data for IDE link testing

    def initialize
      # Telegram
      @telegram_bot_token = ENV.fetch("PG_REPORTS_TELEGRAM_TOKEN", nil)
      @telegram_chat_id = ENV.fetch("PG_REPORTS_TELEGRAM_CHAT_ID", nil)

      # Query thresholds
      @slow_query_threshold_ms = 100
      @heavy_query_threshold_calls = 1000
      @expensive_query_threshold_ms = 10_000

      # Index thresholds
      @unused_index_threshold_scans = 50

      # Table thresholds
      @bloat_threshold_percent = 20
      @dead_rows_threshold = 10_000

      # Connection
      @connection_pool = nil

      # Output
      @max_query_length = 200

      # Dashboard
      @dashboard_auth = nil

      # Assets / privacy
      @load_external_fonts = ActiveModel::Type::Boolean.new.cast(ENV.fetch("PG_REPORTS_LOAD_EXTERNAL_FONTS", false))

      # Development/testing
      @fake_source_data = ENV.fetch("PG_REPORTS_FAKE_SOURCE_DATA", "false") == "true"
    end

    def connection
      @connection_pool || ActiveRecord::Base.connection
    end

    def telegram_configured?
      telegram_bot_token.present? && telegram_chat_id.present?
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def config
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
