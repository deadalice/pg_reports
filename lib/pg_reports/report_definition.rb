# frozen_string_literal: true

module PgReports
  # Parses YAML report definitions and generates Report objects
  class ReportDefinition
    attr_reader :config

    def initialize(yaml_path)
      @config = YAML.load_file(yaml_path)["report"]
      @yaml_path = yaml_path
    end

    def generate_report(**params)
      # 1. Execute SQL
      data = execute_sql(**params)

      # 2. Apply filters
      data = apply_filters(data, params)

      # 3. Apply enrichment
      data = apply_enrichment(data) if enrichment?

      # 4. Apply limit
      limit = params[:limit] || default_limit
      data = data.first(limit) if limit && data.respond_to?(:first)

      # 5. Create Report
      Report.new(
        title: interpolate_title(params),
        data: data,
        columns: config["columns"]
      )
    end

    private

    def execute_sql(**params)
      sql_config = config["sql"]
      sql_params = extract_sql_params(params)

      executor = Executor.new
      executor.execute_from_file(
        sql_config["category"].to_sym,
        sql_config["file"].to_sym,
        **sql_params
      )
    end

    def extract_sql_params(params)
      return {} unless config["sql"]["params"]

      config["sql"]["params"].each_with_object({}) do |(key, value_config), result|
        result[key.to_sym] = resolve_value(value_config, params)
      end
    end

    def apply_filters(data, params)
      return data unless config["filters"]

      config["filters"].reduce(data) do |filtered, filter_config|
        Filter.new(filter_config).apply(filtered, params)
      end
    end

    def enrichment?
      config["enrichment"].present?
    end

    def apply_enrichment(data)
      enrichment = config["enrichment"]
      module_name = enrichment["module"]
      hook_name = enrichment["hook"]

      # Call private method from module
      module_class = PgReports::Modules.const_get(module_name.capitalize)
      module_class.send(hook_name, data)
    end

    def interpolate_title(params)
      title = config["title"]
      return title unless config["title_vars"]

      config["title_vars"].each do |var_name, var_config|
        value = resolve_value(var_config, params)
        title = title.gsub("${#{var_name}}", value.to_s)
      end

      title
    end

    def resolve_value(value_config, params)
      case value_config["source"]
      when "config"
        PgReports.config.public_send(value_config["key"])
      when "param"
        key = value_config["key"].to_sym
        # Try to get from params, fallback to default value
        params[key] || get_default_param_value(key)
      else
        raise ArgumentError, "Unknown value source: #{value_config["source"]}"
      end
    end

    def get_default_param_value(param_key)
      return nil unless config["parameters"]&.dig(param_key.to_s)

      config["parameters"][param_key.to_s]["default"]
    end

    def default_limit
      return nil unless config["parameters"]&.dig("limit")

      config["parameters"]["limit"]["default"]
    end

    public

    # Extract filter parameters for UI
    def filter_parameters
      params = {}

      # Parameters from parameters section
      if config["parameters"]
        config["parameters"].each do |name, param_config|
          params[name] = {
            type: param_config["type"],
            default: param_config["default"],
            description: param_config["description"],
            label: name.to_s.titleize
          }
        end
      end

      # Add threshold parameters from filters (config-based)
      if config["filters"]
        config["filters"].each do |filter|
          if filter["value"]["source"] == "config"
            config_key = filter["value"]["key"]
            field_name = filter["field"]

            params["#{field_name}_threshold"] = {
              type: filter["cast"] || "integer",
              default: PgReports.config.public_send(config_key),
              description: "Override threshold for #{field_name}",
              label: "#{field_name.titleize} Threshold",
              current_config: PgReports.config.public_send(config_key),
              is_threshold: true
            }
          end
        end
      end

      params
    end

    # Extract problem explanations mapping from YAML
    def problem_explanations
      config["problem_explanations"] || {}
    end
  end
end
