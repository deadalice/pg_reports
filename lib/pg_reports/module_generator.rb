# frozen_string_literal: true

module PgReports
  # Generates module methods dynamically from YAML report definitions
  class ModuleGenerator
    def self.generate!
      ReportLoader.load_all.each do |module_name, reports|
        module_class = get_module(module_name)
        next unless module_class

        reports.each do |report_name, definition|
          define_report_method(module_class, report_name, definition)
        end
      end
    end

    private

    def self.get_module(module_name)
      PgReports::Modules.const_get(module_name.capitalize)
    rescue NameError
      # Module doesn't exist, skip it
      # We don't auto-create modules to avoid conflicts
      nil
    end

    def self.define_report_method(module_class, report_name, definition)
      params_config = definition.config["parameters"] || {}

      # Extract default parameter values
      defaults = params_config.transform_values { |v| v["default"] }

      # Define the method on the module
      # We capture the definition in a local variable to avoid closure issues
      captured_definition = definition
      captured_defaults = defaults

      module_class.define_singleton_method(report_name) do |**params|
        merged_params = captured_defaults.merge(params)
        captured_definition.generate_report(**merged_params)
      end
    end
  end
end
