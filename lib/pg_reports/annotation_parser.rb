# frozen_string_literal: true

module PgReports
  # Parses SQL query comments to extract source location and metadata
  # Supports:
  # - PgReports format: /*app:myapp,file:app/models/user.rb,line:42,method:find_active*/
  # - Marginalia format: /*application:myapp,controller:users,action:index*/
  # - Rails QueryLogs: /*action='index',controller='users'*/
  #
  module AnnotationParser
    class << self
      # Parse annotation from query text
      # @param query [String] SQL query text
      # @return [Hash] Parsed annotation data
      def parse(query)
        return {} if query.nil? || query.empty?

        # Extract all comments from query
        comments = query.scan(%r{/\*(.+?)\*/}).flatten

        return {} if comments.empty?

        result = {}

        comments.each do |comment|
          parsed = parse_comment(comment)
          result.merge!(parsed)
        end

        result
      end

      # Extract clean query without annotations
      # @param query [String] SQL query with annotations
      # @return [String] Clean query
      def strip_annotations(query)
        return query if query.nil?

        query.gsub(%r{/\*.+?\*/\s*}, "").strip
      end

      # Format annotation for display
      # @param annotation [Hash] Parsed annotation
      # @return [String] Human-readable string
      def format_for_display(annotation)
        return nil if annotation.empty?

        parts = []

        # Source location
        if annotation[:file]
          loc = annotation[:file].to_s
          loc += ":#{annotation[:line]}" if annotation[:line]
          parts << loc
        end

        # Method
        parts << "##{annotation[:method]}" if annotation[:method]

        # Controller/action
        if annotation[:controller]
          ca = annotation[:controller].to_s
          ca += "##{annotation[:action]}" if annotation[:action]
          parts << ca
        end

        # Application name
        parts << "[#{annotation[:app] || annotation[:application]}]" if annotation[:app] || annotation[:application]

        parts.join(" ")
      end

      private

      def parse_comment(comment)
        result = {}

        # Try different formats

        # Format 1: key:value,key:value (Marginalia/PgReports style)
        if comment.include?(":")
          comment.split(",").each do |pair|
            key, value = pair.split(":", 2)
            next unless key && value

            key = normalize_key(key.strip)
            result[key] = value.strip
          end
        end

        # Format 2: key='value',key='value' (Rails QueryLogs style)
        if comment.include?("=")
          comment.scan(/(\w+)='([^']*)'/).each do |key, value|
            key = normalize_key(key)
            result[key] = value
          end

          comment.scan(/(\w+)="([^"]*)"/).each do |key, value|
            key = normalize_key(key)
            result[key] = value
          end
        end

        result
      end

      def normalize_key(key)
        key.downcase.gsub(/[-\s]/, "_").to_sym
      end
    end
  end
end
