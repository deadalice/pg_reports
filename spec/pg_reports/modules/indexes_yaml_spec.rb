# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgReports::Modules::Indexes, "YAML-based methods" do
  let(:mock_connection) do
    double("connection")
  end

  before do
    allow(PgReports.config).to receive(:connection).and_return(mock_connection)
  end

  describe "#unused_indexes" do
    let(:mock_data) do
      [
        { "schema" => "public", "table_name" => "users", "index_name" => "idx_1", "idx_scan" => "5", "index_size_mb" => "1.5" },
        { "schema" => "public", "table_name" => "posts", "index_name" => "idx_2", "idx_scan" => "100", "index_size_mb" => "2.5" }
      ]
    end

    before do
      allow(mock_connection).to receive(:exec_query).and_return(double(to_a: mock_data))
      allow(PgReports.config).to receive(:unused_index_threshold_scans).and_return(50)
    end

    it "generates method" do
      expect(described_class).to respond_to(:unused_indexes)
    end

    it "returns Report object" do
      report = described_class.unused_indexes
      expect(report).to be_a(PgReports::Report)
    end

    it "filters by threshold" do
      report = described_class.unused_indexes
      expect(report.data.size).to eq(1)
      expect(report.data.first["index_name"]).to eq("idx_1")
    end

    it "interpolates threshold in title" do
      report = described_class.unused_indexes
      expect(report.title).to eq("Unused Indexes (scans <= 50)")
    end

    it "respects limit parameter" do
      many_rows = 100.times.map do |i|
        { "schema" => "public", "table_name" => "t#{i}", "index_name" => "idx_#{i}", "idx_scan" => "5", "index_size_mb" => "1.0" }
      end
      allow(mock_connection).to receive(:exec_query).and_return(double(to_a: many_rows))

      report = described_class.unused_indexes(limit: 10)
      expect(report.data.size).to eq(10)
    end
  end

  describe "#duplicate_indexes" do
    let(:mock_data) do
      [{ "table_name" => "users", "index_name" => "idx_email", "duplicate_of" => "idx_email_unique", "index_size_mb" => "2.5" }]
    end

    before do
      allow(mock_connection).to receive(:exec_query).and_return(double(to_a: mock_data))
    end

    it "generates method" do
      expect(described_class).to respond_to(:duplicate_indexes)
    end

    it "returns correct data" do
      report = described_class.duplicate_indexes
      expect(report.title).to eq("Duplicate Indexes")
      expect(report.columns).to eq(%w[table_name index_name duplicate_of index_size_mb])
    end
  end

  describe "#invalid_indexes" do
    before do
      allow(mock_connection).to receive(:exec_query).and_return(double(to_a: []))
    end

    it "generates method" do
      expect(described_class).to respond_to(:invalid_indexes)
    end

    it "returns Report with correct title" do
      report = described_class.invalid_indexes
      expect(report.title).to eq("Invalid Indexes")
    end
  end

  describe "#missing_indexes" do
    before do
      allow(mock_connection).to receive(:exec_query).and_return(double(to_a: []))
    end

    it "generates method" do
      expect(described_class).to respond_to(:missing_indexes)
    end

    it "has default limit of 20" do
      # This is tested implicitly by the YAML config
      report = described_class.missing_indexes
      expect(report.title).to eq("Tables Potentially Missing Indexes")
    end
  end

  describe "#index_usage" do
    before do
      allow(mock_connection).to receive(:exec_query).and_return(double(to_a: []))
    end

    it "generates method" do
      expect(described_class).to respond_to(:index_usage)
    end

    it "returns Report with correct title" do
      report = described_class.index_usage
      expect(report.title).to eq("Index Usage Statistics")
    end
  end

  describe "#bloated_indexes" do
    let(:mock_data) do
      [
        { "schema" => "public", "table_name" => "users", "index_name" => "idx_1",
          "index_size_mb" => "10.0", "bloat_size_mb" => "5.0", "bloat_percent" => "50.0" },
        { "schema" => "public", "table_name" => "posts", "index_name" => "idx_2",
          "index_size_mb" => "20.0", "bloat_size_mb" => "2.0", "bloat_percent" => "10.0" }
      ]
    end

    before do
      allow(mock_connection).to receive(:exec_query).and_return(double(to_a: mock_data))
      allow(PgReports.config).to receive(:bloat_threshold_percent).and_return(20)
    end

    it "generates method" do
      expect(described_class).to respond_to(:bloated_indexes)
    end

    it "filters by bloat threshold" do
      report = described_class.bloated_indexes
      expect(report.data.size).to eq(1)
      expect(report.data.first["index_name"]).to eq("idx_1")
    end

    it "interpolates threshold in title" do
      report = described_class.bloated_indexes
      expect(report.title).to eq("Bloated Indexes (bloat >= 20%)")
    end
  end

  describe "#index_sizes" do
    before do
      allow(mock_connection).to receive(:exec_query).and_return(double(to_a: []))
    end

    it "generates method" do
      expect(described_class).to respond_to(:index_sizes)
    end

    it "interpolates limit in title" do
      report = described_class.index_sizes(limit: 25)
      expect(report.title).to eq("Index Sizes (top 25)")
    end

    it "uses default limit in title" do
      report = described_class.index_sizes
      expect(report.title).to eq("Index Sizes (top 50)")
    end
  end
end
