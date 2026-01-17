# frozen_string_literal: true

module PgReports
  # Base error class for PgReports
  class Error < StandardError; end

  # Raised when Telegram is not configured
  class TelegramNotConfiguredError < Error; end

  # Raised when SQL file is not found
  class SqlFileNotFoundError < Error; end

  # Raised when database connection fails
  class ConnectionError < Error; end
end
