# frozen_string_literal: true

module PgReports
  # Checks runtime environment and warns about outdated or unsupported versions.
  # Called once at boot (Ruby/Rails) and lazily on first DB access (PostgreSQL).
  module Compatibility
    # Keep in sync with gemspec constraints
    MINIMUM_RUBY_VERSION = "2.7"
    MINIMUM_RAILS_VERSION = "5.0"
    MINIMUM_PG_VERSION = 12_00_00  # server_version_num format
    MINIMUM_PG_VERSION_LABEL = "12"

    class << self
      def check_ruby!
        return if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(MINIMUM_RUBY_VERSION)

        warn "[pg_reports] Ruby #{RUBY_VERSION} is not supported. " \
             "Minimum required version is Ruby #{MINIMUM_RUBY_VERSION}."
      end

      def check_rails!
        return unless defined?(Rails::VERSION::STRING)
        return if Gem::Version.new(Rails::VERSION::STRING) >= Gem::Version.new(MINIMUM_RAILS_VERSION)

        warn "[pg_reports] Rails #{Rails::VERSION::STRING} is not supported. " \
             "Minimum required version is Rails #{MINIMUM_RAILS_VERSION}."
      end

      def check_postgresql!
        version_num = pg_version_num
        return if version_num.nil? # no connection yet — skip silently
        return if version_num >= MINIMUM_PG_VERSION

        label = pg_version_label(version_num)
        warn "[pg_reports] PostgreSQL #{label} is not supported. " \
             "Minimum required version is PostgreSQL #{MINIMUM_PG_VERSION_LABEL}. " \
             "Some reports may return errors or incomplete data."
      end

      def check_all!
        check_ruby!
        check_rails!
        check_postgresql!
      end

      private

      def pg_version_num
        connection = PgReports.config.connection
        result = connection.exec_query("SELECT current_setting('server_version_num')::int AS v")
        result.first&.fetch("v", 0).to_i
      rescue
        nil
      end

      def pg_version_label(version_num)
        major = version_num / 1_00_00
        minor = (version_num % 1_00_00) / 100
        "#{major}.#{minor}"
      end
    end
  end
end
