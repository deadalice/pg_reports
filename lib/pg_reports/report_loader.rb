# frozen_string_literal: true

require "pathname"

module PgReports
  # Loads YAML report definitions from the definitions directory
  class ReportLoader
    def self.load_all
      @definitions ||= begin
        definitions = {}

        Dir.glob(definitions_path.join("**/*.yml")).each do |yaml_file|
          definition = ReportDefinition.new(yaml_file)
          module_name = definition.config["module"]
          report_name = definition.config["name"]

          definitions[module_name] ||= {}
          definitions[module_name][report_name] = definition
        end

        definitions
      end
    end

    def self.get(module_name, report_name)
      load_all.dig(module_name.to_s, report_name.to_s)
    end

    def self.definitions_path
      Pathname.new(__dir__).join("definitions")
    end

    def self.reload!
      @definitions = nil
      load_all
    end
  end
end
