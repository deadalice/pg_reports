# frozen_string_literal: true

require "cgi"

module PgReports
  # Report class that wraps query results and provides display/send methods
  # Every module method returns a Report instance for chaining
  class Report
    attr_reader :title, :data, :columns, :generated_at

    def initialize(title:, data:, columns: nil)
      @title = title
      @data = data
      @columns = columns || detect_columns
      @generated_at = Time.current
    end

    # Display report to STDOUT
    def display
      puts to_text
    end

    # Send report to configured Telegram channel as a message
    def send_to_telegram
      TelegramSender.send_message(to_markdown)
      self
    end

    # Send report to configured Telegram channel as a file
    def send_to_telegram_as_file(filename: nil)
      filename ||= "#{title.parameterize}-#{generated_at.strftime("%Y%m%d-%H%M%S")}.txt"
      TelegramSender.send_file(to_text, filename: filename, caption: title)
      self
    end

    # Return plain text representation
    def to_text
      return empty_report_text if data.empty?

      lines = []
      lines << title
      lines << "=" * title.length
      lines << "Generated: #{generated_at.strftime("%Y-%m-%d %H:%M:%S")}"
      lines << ""
      lines << format_table_text
      lines << ""
      lines << "Total: #{data.size} rows"

      lines.join("\n")
    end

    # Return Markdown representation
    def to_markdown
      return empty_report_markdown if data.empty?

      lines = []
      lines << "**#{title}**"
      lines << "_Generated: #{generated_at.strftime("%Y-%m-%d %H:%M:%S")}_"
      lines << ""
      lines << format_table_markdown
      lines << ""
      lines << "_Total: #{data.size} rows_"

      lines.join("\n")
    end

    # Return HTML representation
    def to_html
      return empty_report_html if data.empty?

      lines = []
      lines << "<h2>#{CGI.escapeHTML(title)}</h2>"
      lines << "<p><em>Generated: #{generated_at.strftime("%Y-%m-%d %H:%M:%S")}</em></p>"
      lines << format_table_html
      lines << "<p><em>Total: #{data.size} rows</em></p>"

      lines.join("\n")
    end

    # Return CSV representation
    def to_csv
      require "csv"

      CSV.generate do |csv|
        csv << columns
        data.each do |row|
          csv << columns.map { |col| row[col] }
        end
      end
    end

    # Get raw data as array of hashes
    def to_a
      data
    end

    # Check if report is empty
    def empty?
      data.empty?
    end

    # Get row count
    def size
      data.size
    end

    alias_method :length, :size
    alias_method :count, :size

    # Iterate over rows
    def each(&block)
      data.each(&block)
    end

    include Enumerable

    private

    def detect_columns
      return [] if data.empty?

      data.first.keys
    end

    def empty_report_text
      "#{title}\n#{"=" * title.length}\nNo data found."
    end

    def empty_report_markdown
      "**#{title}**\n\n_No data found._"
    end

    def empty_report_html
      "<h2>#{CGI.escapeHTML(title)}</h2>\n<p><em>No data found.</em></p>"
    end

    def format_table_text
      return "" if data.empty?

      # Calculate column widths
      widths = calculate_column_widths

      # Build header
      header = columns.map.with_index { |col, i| col.to_s.ljust(widths[i]) }.join(" | ")
      separator = widths.map { |w| "-" * w }.join("-+-")

      # Build rows
      rows = data.map do |row|
        columns.map.with_index do |col, i|
          format_cell(row[col]).to_s.ljust(widths[i])
        end.join(" | ")
      end

      [header, separator, *rows].join("\n")
    end

    def format_table_markdown
      return "" if data.empty?

      # Markdown table header
      header = "| " + columns.map(&:to_s).join(" | ") + " |"
      separator = "| " + columns.map { "---" }.join(" | ") + " |"

      # Build rows (limit for Telegram message size)
      limited_data = data.first(50)
      rows = limited_data.map do |row|
        "| " + columns.map { |col| format_cell(row[col]) }.join(" | ") + " |"
      end

      result = [header, separator, *rows]
      result << "| ... and #{data.size - 50} more rows |" if data.size > 50

      result.join("\n")
    end

    def format_table_html
      return "" if data.empty?

      lines = ["<table>"]

      # Header
      lines << "<thead><tr>"
      columns.each { |col| lines << "<th>#{CGI.escapeHTML(col.to_s)}</th>" }
      lines << "</tr></thead>"

      # Body
      lines << "<tbody>"
      data.each do |row|
        lines << "<tr>"
        columns.each { |col| lines << "<td>#{CGI.escapeHTML(format_cell(row[col]))}</td>" }
        lines << "</tr>"
      end
      lines << "</tbody>"

      lines << "</table>"
      lines.join("\n")
    end

    def calculate_column_widths
      columns.map.with_index do |col, _i|
        values = data.map { |row| format_cell(row[col]).to_s.length }
        [col.to_s.length, *values].max
      end
    end

    def format_cell(value)
      case value
      when nil
        ""
      when Float
        format("%.2f", value)
      when Time, DateTime
        value.strftime("%Y-%m-%d %H:%M:%S")
      when String
        truncate_query(value)
      else
        value.to_s
      end
    end

    def truncate_query(text)
      max_length = PgReports.config.max_query_length
      return text if text.length <= max_length

      "#{text[0, max_length - 3]}..."
    end
  end
end
