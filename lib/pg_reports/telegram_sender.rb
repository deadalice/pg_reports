# frozen_string_literal: true

require "tempfile"

module PgReports
  # Sends reports to Telegram using telegram-bot-ruby gem
  module TelegramSender
    class << self
      def send_message(text, parse_mode: "Markdown")
        ensure_configured!
        ensure_telegram_gem!

        bot.api.send_message(
          chat_id: chat_id,
          text: truncate_message(text),
          parse_mode: parse_mode
        )
      end

      def send_file(content, filename:, caption: nil)
        ensure_configured!
        ensure_telegram_gem!

        # Create a temporary file
        temp_file = Tempfile.new([File.basename(filename, ".*"), File.extname(filename)])
        begin
          temp_file.write(content)
          temp_file.rewind

          bot.api.send_document(
            chat_id: chat_id,
            document: Faraday::UploadIO.new(temp_file.path, "text/plain", filename),
            caption: caption&.truncate(1024)
          )
        ensure
          temp_file.close
          temp_file.unlink
        end
      end

      def send_report(report)
        if report.to_text.length > 4000
          send_file(report.to_text, filename: report_filename(report), caption: report.title)
        else
          send_message(report.to_markdown)
        end
      end

      private

      def bot
        @bot ||= Telegram::Bot::Client.new(PgReports.config.telegram_bot_token)
      end

      def chat_id
        PgReports.config.telegram_chat_id
      end

      def ensure_configured!
        unless PgReports.config.telegram_configured?
          raise TelegramNotConfiguredError, "Telegram is not configured. Set telegram_bot_token and telegram_chat_id."
        end
      end

      def ensure_telegram_gem!
        unless defined?(Telegram::Bot)
          raise Error, "telegram-bot-ruby gem is not installed. Add it to your Gemfile: gem 'telegram-bot-ruby'"
        end
      end

      def truncate_message(text)
        # Telegram message limit is 4096 characters
        return text if text.length <= 4096

        "#{text[0, 4000]}...\n\n_Message truncated. Use send_to_telegram_as_file for full report._"
      end

      def report_filename(report)
        "#{report.title.parameterize}-#{report.generated_at.strftime("%Y%m%d-%H%M%S")}.txt"
      end
    end
  end
end
