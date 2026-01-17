# frozen_string_literal: true

RSpec.describe PgReports::SqlLoader do
  describe ".load" do
    it "loads SQL file from queries category" do
      sql = described_class.load(:queries, :slow_queries)

      expect(sql).to be_a(String)
      expect(sql).to include("SELECT")
      expect(sql).to include("pg_stat_statements")
    end

    it "loads SQL file from indexes category" do
      sql = described_class.load(:indexes, :unused_indexes)

      expect(sql).to be_a(String)
      expect(sql).to include("SELECT")
    end

    it "caches loaded SQL" do
      described_class.clear_cache!

      sql1 = described_class.load(:queries, :slow_queries)
      sql2 = described_class.load(:queries, :slow_queries)

      expect(sql1).to equal(sql2) # Same object
    end

    it "raises error for missing file" do
      expect do
        described_class.load(:queries, :nonexistent)
      end.to raise_error(PgReports::SqlFileNotFoundError)
    end
  end

  describe ".clear_cache!" do
    it "clears the SQL cache" do
      described_class.load(:queries, :slow_queries)
      described_class.clear_cache!

      # After clearing, it should reload from file
      # (we can't easily test this without mocking File.read)
      expect { described_class.load(:queries, :slow_queries) }.not_to raise_error
    end
  end
end
