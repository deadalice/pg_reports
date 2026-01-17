# frozen_string_literal: true

module PgReports
  # Executes SQL queries and returns results
  class Executor
    def initialize(connection: nil)
      @connection = connection || PgReports.config.connection
    end

    # Execute SQL from a file and return results as array of hashes
    def execute_from_file(category, name, **params)
      sql = SqlLoader.load(category, name)
      execute(sql, **params)
    end

    # Execute raw SQL and return results as array of hashes
    def execute(sql, **params)
      processed_sql = interpolate_params(sql, params)
      result = @connection.exec_query(processed_sql)
      result.to_a
    end

    private

    # Simple parameter interpolation for SQL
    # Replaces :param_name with quoted values
    def interpolate_params(sql, params)
      return sql if params.empty?

      params.reduce(sql) do |query, (key, value)|
        quoted_value = quote_value(value)
        query.gsub(":#{key}", quoted_value)
      end
    end

    def quote_value(value)
      case value
      when nil
        "NULL"
      when Integer, Float
        value.to_s
      when String
        @connection.quote(value)
      when Array
        "(#{value.map { |v| quote_value(v) }.join(", ")})"
      else
        @connection.quote(value.to_s)
      end
    end
  end
end
