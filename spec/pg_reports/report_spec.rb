# frozen_string_literal: true

RSpec.describe PgReports::Report do
  let(:data) do
    [
      {"name" => "Alice", "age" => 30},
      {"name" => "Bob", "age" => 25}
    ]
  end

  subject(:report) do
    described_class.new(
      title: "Test Report",
      data: data,
      columns: %w[name age]
    )
  end

  describe "#initialize" do
    it "sets title" do
      expect(report.title).to eq("Test Report")
    end

    it "sets data" do
      expect(report.data).to eq(data)
    end

    it "sets columns" do
      expect(report.columns).to eq(%w[name age])
    end

    it "sets generated_at" do
      expect(report.generated_at).to be_within(1.second).of(Time.current)
    end

    it "auto-detects columns if not provided" do
      report = described_class.new(title: "Test", data: data)
      expect(report.columns).to eq(%w[name age])
    end
  end

  describe "#size" do
    it "returns number of rows" do
      expect(report.size).to eq(2)
    end
  end

  describe "#empty?" do
    it "returns false when data present" do
      expect(report.empty?).to be false
    end

    it "returns true when no data" do
      empty_report = described_class.new(title: "Empty", data: [])
      expect(empty_report.empty?).to be true
    end
  end

  describe "#to_text" do
    it "includes title" do
      expect(report.to_text).to include("Test Report")
    end

    it "includes data" do
      text = report.to_text
      expect(text).to include("Alice")
      expect(text).to include("Bob")
    end

    it "includes total count" do
      expect(report.to_text).to include("Total: 2 rows")
    end
  end

  describe "#to_markdown" do
    it "formats title as bold" do
      expect(report.to_markdown).to include("**Test Report**")
    end

    it "includes markdown table" do
      markdown = report.to_markdown
      expect(markdown).to include("| name | age |")
      expect(markdown).to include("| --- | --- |")
    end
  end

  describe "#to_csv" do
    it "generates valid CSV" do
      csv = report.to_csv
      expect(csv).to include("name,age")
      expect(csv).to include("Alice,30")
      expect(csv).to include("Bob,25")
    end
  end

  describe "#to_a" do
    it "returns raw data" do
      expect(report.to_a).to eq(data)
    end
  end

  describe "Enumerable" do
    it "includes Enumerable" do
      expect(report).to be_a(Enumerable)
    end

    it "iterates over rows" do
      names = report.map { |row| row["name"] }
      expect(names).to eq(%w[Alice Bob])
    end
  end
end
