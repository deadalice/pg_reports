# frozen_string_literal: true

RSpec.describe PgReports::Modules::SchemaAnalysis do
  # Pure helpers exercised via `send` since they're declared private.
  # If you find yourself adding many of these, consider extracting them
  # into a separate value object with a public API.

  describe "#classify_orphan" do
    column = Struct.new(:name)

    define_method(:cols) do |*names|
      names.map { |n| column.new(n) }
    end

    it "classifies a clean two-FK table as join_table_candidate" do
      result = described_class.send(:classify_orphan, cols("user_id", "role_id"))
      expect(result).to eq("join_table_candidate")
    end

    it "classifies a two-FK table with timestamps as join_table_candidate" do
      result = described_class.send(:classify_orphan, cols("user_id", "role_id", "created_at", "updated_at"))
      expect(result).to eq("join_table_candidate")
    end

    it "classifies a two-FK table with id and extra fields as join_model_without_class" do
      result = described_class.send(:classify_orphan, cols("id", "user_id", "role_id", "granted_by_id", "expires_at"))
      expect(result).to eq("join_model_without_class")
    end

    it "classifies a single-FK table as legacy" do
      result = described_class.send(:classify_orphan, cols("id", "user_id", "data"))
      expect(result).to eq("legacy")
    end

    it "classifies a no-FK table as legacy" do
      result = described_class.send(:classify_orphan, cols("id", "name", "value"))
      expect(result).to eq("legacy")
    end
  end

  describe "#coverage_label" do
    index = Struct.new(:columns)

    it "returns 'neither indexed' when no relevant indexes exist" do
      indexes = [index.new(["id"]), index.new(["created_at"])]
      result = described_class.send(:coverage_label, indexes, "commentable_type", "commentable_id")
      expect(result).to eq("neither indexed")
    end

    it "detects only-id coverage" do
      indexes = [index.new(["commentable_id"])]
      result = described_class.send(:coverage_label, indexes, "commentable_type", "commentable_id")
      expect(result).to eq("only id indexed")
    end

    it "detects only-type coverage" do
      indexes = [index.new(["commentable_type"])]
      result = described_class.send(:coverage_label, indexes, "commentable_type", "commentable_id")
      expect(result).to eq("only type indexed")
    end

    it "detects separate single-column indexes for both" do
      indexes = [index.new(["commentable_type"]), index.new(["commentable_id"])]
      result = described_class.send(:coverage_label, indexes, "commentable_type", "commentable_id")
      expect(result).to eq("type and id indexed separately")
    end

    it "ignores indexes where the relevant column is not the leading column" do
      # An index on (other, commentable_id) does not give us type-and-id coverage on its own
      indexes = [index.new(["other_col", "commentable_id"])]
      result = described_class.send(:coverage_label, indexes, "commentable_type", "commentable_id")
      expect(result).to eq("neither indexed")
    end

    it "does not crash on expression indexes whose columns is a String" do
      # PostgreSQL expression indexes (e.g. CREATE INDEX ON users (LOWER(email)))
      # are returned with `columns` as a String, not an Array.
      indexes = [index.new("LOWER(commentable_type)"), index.new(["commentable_id"])]
      expect {
        described_class.send(:coverage_label, indexes, "commentable_type", "commentable_id")
      }.not_to raise_error
    end
  end

  describe "#counter_cache_column_name" do
    let(:child_model) { instance_double("Model", table_name: "comments") }

    def assoc(option)
      double("Reflection", options: {counter_cache: option})
    end

    it "returns '<child_table>_count' for counter_cache: true" do
      result = described_class.send(:counter_cache_column_name, child_model, assoc(true))
      expect(result).to eq("comments_count")
    end

    it "returns the explicit column name when counter_cache is a symbol" do
      result = described_class.send(:counter_cache_column_name, child_model, assoc(:total_comments))
      expect(result).to eq("total_comments")
    end

    it "returns the explicit column name when counter_cache is a string" do
      result = described_class.send(:counter_cache_column_name, child_model, assoc("comment_total"))
      expect(result).to eq("comment_total")
    end

    it "strips schema prefix from table_name when computing default counter column" do
      schema_qualified = instance_double("Model", table_name: "public.comments")
      result = described_class.send(:counter_cache_column_name, schema_qualified, assoc(true))
      expect(result).to eq("comments_count")
    end

    it "extracts the column name from the Rails 7.1+ Hash form" do
      result = described_class.send(:counter_cache_column_name, child_model, assoc({active: true, column: "usage_count"}))
      expect(result).to eq("usage_count")
    end

    it "supports the Hash form with string keys" do
      result = described_class.send(:counter_cache_column_name, child_model, assoc({"active" => true, "column" => "usage_count"}))
      expect(result).to eq("usage_count")
    end

    it "falls back to the default when the Hash form omits :column" do
      result = described_class.send(:counter_cache_column_name, child_model, assoc({active: true}))
      expect(result).to eq("comments_count")
    end
  end

  describe "#internal_table?" do
    it "flags Rails internal tables" do
      expect(described_class.send(:internal_table?, "schema_migrations")).to be true
      expect(described_class.send(:internal_table?, "ar_internal_metadata")).to be true
    end

    it "does not flag user tables" do
      expect(described_class.send(:internal_table?, "users")).to be false
      expect(described_class.send(:internal_table?, "comments")).to be false
    end
  end
end
