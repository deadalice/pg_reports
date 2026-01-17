# frozen_string_literal: true

module PgReports
  # Loads and caches SQL queries from files
  module SqlLoader
    SQL_DIR = File.expand_path("sql", __dir__)

    class << self
      def load(category, name)
        cache_key = "#{category}/#{name}"
        sql_cache[cache_key] ||= read_sql_file(category, name)
      end

      def clear_cache!
        @sql_cache = {}
      end

      private

      def sql_cache
        @sql_cache ||= {}
      end

      def read_sql_file(category, name)
        path = File.join(SQL_DIR, category.to_s, "#{name}.sql")

        unless File.exist?(path)
          raise SqlFileNotFoundError, "SQL file not found: #{path}"
        end

        File.read(path)
      end
    end
  end
end
