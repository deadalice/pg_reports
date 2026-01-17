# frozen_string_literal: true

RSpec.describe PgReports::Dashboard::ReportsRegistry do
  describe ".all" do
    it "returns all report categories" do
      all = described_class.all

      expect(all).to be_a(Hash)
      expect(all.keys).to include(:queries, :indexes, :tables, :connections, :system)
    end

    it "each category has required fields" do
      described_class.all.each do |_key, category|
        expect(category).to have_key(:name)
        expect(category).to have_key(:icon)
        expect(category).to have_key(:color)
        expect(category).to have_key(:reports)
      end
    end
  end

  describe ".find" do
    it "finds existing report" do
      report = described_class.find(:queries, :slow_queries)

      expect(report).to be_a(Hash)
      expect(report[:name]).to eq("Slow Queries")
      expect(report[:description]).to be_present
    end

    it "returns nil for non-existent report" do
      report = described_class.find(:queries, :nonexistent)

      expect(report).to be_nil
    end

    it "returns nil for non-existent category" do
      report = described_class.find(:nonexistent, :slow_queries)

      expect(report).to be_nil
    end
  end

  describe ".category" do
    it "returns category by key" do
      category = described_class.category(:queries)

      expect(category[:name]).to eq("Queries")
      expect(category[:reports]).to be_a(Hash)
    end

    it "returns nil for non-existent category" do
      category = described_class.category(:nonexistent)

      expect(category).to be_nil
    end
  end
end
