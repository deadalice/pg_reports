# frozen_string_literal: true

module PgReports
  # Executes SQL queries and returns results.
  #
  # The connection is resolved lazily on every #execute call so that thread-local
  # context set by PgReports.with_target / with_database is honored even when an
  # Executor instance has been memoized at the module level.
  class Executor
    def initialize(connection: nil)
      @connection_override = connection
    end

    # Execute SQL from a file and return results as array of hashes
    def execute_from_file(category, name, **params)
      sql = SqlLoader.load(category, name)
      execute(sql, **params)
    end

    # Execute raw SQL and return results as array of hashes.
    #
    # Every query is tagged with the "PgReports" AR statement name so the Query
    # Monitor can skip our own queries by name (see QueryMonitor#should_skip?),
    # reliably and independent of backtrace depth — the internal live_metrics /
    # status polling would otherwise leak into the monitor's history.
    def execute(sql, **params)
      processed_sql = interpolate_params(sql, params)
      result = connection.exec_query(processed_sql, "PgReports")
      result.to_a
    end

    # Resolved on every call: explicit override > thread-local > registry default.
    def connection
      @connection_override || PgReports.config.connection
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
        connection.quote(value)
      when Array
        "(#{value.map { |v| quote_value(v) }.join(", ")})"
      else
        connection.quote(value.to_s)
      end
    end
  end
end
