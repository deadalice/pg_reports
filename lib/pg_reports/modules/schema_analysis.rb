# frozen_string_literal: true

module PgReports
  module Modules
    # Schema analysis module - validates database schema consistency with application code
    module SchemaAnalysis
      extend self

      # Missing validations - unique indexes without corresponding validations
      # @return [Report] Report with unique indexes missing validations
      def missing_validations
        unique_indexes = executor.execute_from_file(:schema_analysis, :unique_indexes)
        results = []

        unique_indexes.each do |index|
          schema_name = index["schema_name"]
          table_name = index["table_name"]
          index_name = index["index_name"]
          column_names = parse_array(index["column_names"])
          index_type = index["index_type"]

          # Skip primary keys (they don't need validation)
          next if index_type == "primary_key"

          # Try to find the model for this table
          model = find_model_for_table(table_name)

          if model.nil?
            results << {
              "schema" => schema_name,
              "table_name" => table_name,
              "index_name" => index_name,
              "columns" => column_names.join(", "),
              "index_type" => index_type,
              "status" => "no_model",
              "validation_status" => "Model not found",
              "suggestion" => "Create a model for this table or add validates :#{column_names.first}, uniqueness: true"
            }
            next
          end

          # Check if validation exists
          has_validation = check_uniqueness_validation(model, column_names)

          unless has_validation
            results << {
              "schema" => schema_name,
              "table_name" => table_name,
              "model_name" => model.name,
              "index_name" => index_name,
              "columns" => column_names.join(", "),
              "index_type" => index_type,
              "status" => "missing_validation",
              "validation_status" => "Missing uniqueness validation",
              "suggestion" => build_validation_suggestion(column_names)
            }
          end
        end

        Report.new(
          title: "Unique Indexes Missing Validations",
          data: results,
          columns: %w[table_name model_name columns status validation_status]
        )
      end

      private

      def executor
        @executor ||= Executor.new
      end

      # Parse PostgreSQL array string to Ruby array
      def parse_array(array_string)
        return [] if array_string.nil? || array_string.empty?

        # PostgreSQL returns arrays as {val1,val2,val3}
        array_string.gsub(/[{}]/, "").split(",").map(&:strip)
      end

      # Find ActiveRecord model for a given table name
      def find_model_for_table(table_name)
        # Try common naming conventions
        possible_names = [
          table_name.classify,                    # users -> User
          table_name.singularize.classify,        # users -> User
          table_name.camelize,                    # user_profiles -> UserProfile
          table_name.singularize.camelize         # user_profiles -> UserProfile
        ].uniq

        possible_names.each do |model_name|
          model = model_name.constantize
          return model if model.is_a?(Class) && model < ActiveRecord::Base
        rescue NameError
          # Model doesn't exist, try next one
        end

        nil
      end

      # Check if model has uniqueness validation for given columns
      def check_uniqueness_validation(model, column_names)
        return false unless model.respond_to?(:validators)

        # Get all uniqueness validators
        uniqueness_validators = model.validators.select do |v|
          v.is_a?(ActiveRecord::Validations::UniquenessValidator)
        end

        return false if uniqueness_validators.empty?

        # Check if any validator covers our columns
        column_names.each do |column|
          column_sym = column.to_sym

          # Check if this column has a uniqueness validator
          has_validator = uniqueness_validators.any? do |validator|
            validator.attributes.include?(column_sym)
          end

          return false unless has_validator
        end

        # If we have multiple columns, check for composite uniqueness
        if column_names.size > 1
          # For composite indexes, we need to check if there's a validation with scope
          primary_column = column_names.first.to_sym
          scope_columns = column_names[1..-1].map(&:to_sym)

          has_composite = uniqueness_validators.any? do |validator|
            validator.attributes.include?(primary_column) &&
              validator.options[:scope] &&
              Array(validator.options[:scope]).sort == scope_columns.sort
          end

          return has_composite
        end

        true
      end

      # Build validation suggestion based on columns
      def build_validation_suggestion(column_names)
        if column_names.size == 1
          "validates :#{column_names.first}, uniqueness: true"
        else
          primary = column_names.first
          scopes = column_names[1..-1]
          "validates :#{primary}, uniqueness: { scope: #{scopes.inspect} }"
        end
      end
    end
  end
end
