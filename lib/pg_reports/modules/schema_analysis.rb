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

      # Polymorphic associations missing a composite (type, id) index
      # @return [Report]
      def polymorphic_without_index(**_params)
        eager_load_models!
        results = []

        each_concrete_model do |model|
          polymorphic_belongs_to(model).each do |assoc|
            type_col = "#{assoc.name}_type"
            id_col = "#{assoc.name}_id"

            next unless model.column_names.include?(type_col) && model.column_names.include?(id_col)

            # Expression/functional indexes report `columns` as a String — drop them; we only care about column-list indexes.
            indexes = ActiveRecord::Base.connection.indexes(model.table_name).select { |i| i.columns.is_a?(Array) }
            composite = indexes.find { |idx| (idx.columns & [type_col, id_col]).size == 2 }
            next if composite

            results << {
              "schema" => "public",
              "table_name" => model.table_name,
              "model_name" => model.name,
              "association" => assoc.name.to_s,
              "type_column" => type_col,
              "id_column" => id_col,
              "coverage" => coverage_label(indexes, type_col, id_col),
              "suggestion" => "add_index :#{model.table_name}, [:#{type_col}, :#{id_col}]"
            }
          end
        end

        Report.new(
          title: "Polymorphic Associations Without Composite Index",
          data: results,
          columns: %w[table_name model_name association coverage suggestion]
        )
      end

      # belongs_to ..., counter_cache: ... whose counter column is missing on the parent
      # @return [Report]
      def counter_cache_issues(**_params)
        eager_load_models!
        results = []

        each_concrete_model do |model|
          counter_belongs_to(model).each do |assoc|
            counter_col = counter_cache_column_name(model, assoc)
            parent = parent_class_for(assoc)
            next unless parent && parent.table_exists?

            unless parent.column_names.include?(counter_col)
              results << {
                "schema" => "public",
                "child_model" => model.name,
                "child_table" => model.table_name,
                "parent_model" => parent.name,
                "parent_table" => parent.table_name,
                "expected_column" => counter_col,
                "issue" => "missing_column",
                "suggestion" => "add_column :#{parent.table_name}, :#{counter_col}, :integer, default: 0, null: false"
              }
            end
          end
        end

        Report.new(
          title: "Counter Cache Issues",
          data: results,
          columns: %w[child_model parent_model expected_column issue suggestion]
        )
      end

      # Tables with soft-delete column but no model scope filtering it
      # @return [Report]
      def soft_delete_without_scope(**_params)
        eager_load_models!
        soft_delete_columns = %w[deleted_at discarded_at archived_at]
        results = []

        ActiveRecord::Base.connection.tables.each do |table|
          next if internal_table?(table)

          columns = ActiveRecord::Base.connection.columns(table).map(&:name)
          soft_col = (columns & soft_delete_columns).first
          next unless soft_col

          model = find_model_for_table(table)
          if model.nil?
            results << {
              "schema" => "public",
              "table_name" => table,
              "model_name" => "(no model)",
              "soft_delete_column" => soft_col,
              "status" => "no_model",
              "suggestion" => "Create a model or filter manually in queries"
            }
            next
          end

          next if model_filters_soft_delete?(model, soft_col)

          results << {
            "schema" => "public",
            "table_name" => table,
            "model_name" => model.name,
            "soft_delete_column" => soft_col,
            "status" => "no_scope",
            "suggestion" => "default_scope { where(#{soft_col}: nil) } or use discard/paranoia"
          }
        end

        Report.new(
          title: "Soft Delete Without Scope",
          data: results,
          columns: %w[table_name model_name soft_delete_column status suggestion]
        )
      end

      # Tables with no corresponding Rails model (legacy or HABTM)
      # @return [Report]
      def orphan_tables(**_params)
        eager_load_models!
        results = []

        ActiveRecord::Base.connection.tables.each do |table|
          next if internal_table?(table)
          next if find_model_for_table(table)

          columns = ActiveRecord::Base.connection.columns(table)
          row_count = approximate_row_count(table)

          results << {
            "schema" => "public",
            "table_name" => table,
            "row_count" => row_count,
            "column_count" => columns.size,
            "classification" => classify_orphan(columns)
          }
        end

        results.sort_by! { |r| -r["row_count"].to_i }

        Report.new(
          title: "Orphan Tables (No Rails Model)",
          data: results,
          columns: %w[table_name row_count column_count classification]
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
          scope_columns = column_names[1..].map(&:to_sym)

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
          scopes = column_names[1..]
          "validates :#{primary}, uniqueness: { scope: #{scopes.inspect} }"
        end
      end

      # Eager-load all application models so descendants is complete in development
      def eager_load_models!
        return unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application
        Rails.application.eager_load!
      rescue
        # Best-effort; don't crash the report if a model fails to autoload
      end

      # Yield each concrete (non-abstract) ActiveRecord model that has a backing table
      def each_concrete_model
        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?
          next if model.name.nil?
          next unless model.table_exists?
          yield model
        rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished
          # Skip models whose table cannot be inspected
        end
      end

      def polymorphic_belongs_to(model)
        model.reflect_on_all_associations(:belongs_to).select { |a| a.options[:polymorphic] }
      end

      def counter_belongs_to(model)
        model.reflect_on_all_associations(:belongs_to).reject { |a| a.options[:polymorphic] }.select { |a| a.options[:counter_cache] }
      end

      # Resolve the counter_cache column name from belongs_to options.
      # counter_cache: true                                 → "<child_table_name>_count" (Rails default)
      # counter_cache: :col                                 → "col"
      # counter_cache: "col"                                → "col"
      # counter_cache: { active: true, column: "col" }      → "col" (Rails 7.1+ form)
      # counter_cache: { active: true }                     → falls back to default
      def counter_cache_column_name(child_model, assoc)
        opt = assoc.options[:counter_cache]
        column = case opt
        when true
          nil
        when Hash
          opt[:column] || opt["column"]
        else
          opt
        end
        return column.to_s if column

        "#{child_model.table_name.split(".").last}_count"
      end

      def parent_class_for(assoc)
        assoc.klass
      rescue NameError
        nil
      end

      # Does the model's default scope filter out soft-deleted rows on the given column?
      # Detects: paranoia, discard, hand-rolled default_scope referencing the column.
      def model_filters_soft_delete?(model, column)
        return true if model.respond_to?(:paranoid?) && model.paranoid?
        return true if model.respond_to?(:discard_column) && model.discard_column.to_s == column

        default_sql = model.all.to_sql
        default_sql.include?(column)
      rescue
        false
      end

      def coverage_label(indexes, type_col, id_col)
        column_list_indexes = indexes.select { |i| i.columns.is_a?(Array) }
        type_indexed = column_list_indexes.any? { |i| i.columns.first == type_col }
        id_indexed = column_list_indexes.any? { |i| i.columns.first == id_col }

        if type_indexed && id_indexed
          "type and id indexed separately"
        elsif type_indexed
          "only type indexed"
        elsif id_indexed
          "only id indexed"
        else
          "neither indexed"
        end
      end

      def internal_table?(name)
        %w[schema_migrations ar_internal_metadata].include?(name)
      end

      def approximate_row_count(table)
        sql = "SELECT n_live_tup FROM pg_stat_user_tables WHERE relname = #{ActiveRecord::Base.connection.quote(table)}"
        ActiveRecord::Base.connection.select_value(sql).to_i
      rescue
        0
      end

      # Classify an orphan table based on column shape.
      # Two FK columns + nothing else (or just timestamps) → likely HABTM join table.
      def classify_orphan(columns)
        col_names = columns.map(&:name)
        fk_cols = col_names.select { |c| c.end_with?("_id") }
        non_meta = col_names - %w[id created_at updated_at]

        if fk_cols.size == 2 && (non_meta - fk_cols).empty?
          "join_table_candidate"
        elsif fk_cols.size >= 2
          "join_model_without_class"
        else
          "legacy"
        end
      end
    end
  end
end
