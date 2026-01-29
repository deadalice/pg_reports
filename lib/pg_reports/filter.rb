# frozen_string_literal: true

module PgReports
  # Applies filtering logic to report data based on YAML configuration
  class Filter
    OPERATORS = {
      "eq" => ->(a, b) { a == b },
      "ne" => ->(a, b) { a != b },
      "lt" => ->(a, b) { a < b },
      "lte" => ->(a, b) { a <= b },
      "gt" => ->(a, b) { a > b },
      "gte" => ->(a, b) { a >= b }
    }.freeze

    def initialize(config)
      @field = config["field"]
      @operator = config["operator"]
      @value_config = config["value"]
      @cast = config["cast"] || "string"
    end

    def apply(data, params)
      threshold = resolve_value(params)
      operator_fn = OPERATORS[@operator]

      raise ArgumentError, "Unknown operator: #{@operator}" unless operator_fn

      data.select do |row|
        field_value = cast_value(row[@field], @cast)
        operator_fn.call(field_value, threshold)
      end
    end

    private

    def resolve_value(params)
      value = case @value_config["source"]
      when "config"
        PgReports.config.public_send(@value_config["key"])
      when "param"
        params[@value_config["key"].to_sym]
      else
        raise ArgumentError, "Unknown value source: #{@value_config["source"]}"
      end

      cast_value(value, @cast)
    end

    def cast_value(value, type)
      case type
      when "integer" then value.to_i
      when "float" then value.to_f
      when "string" then value.to_s
      else value
      end
    end
  end
end
