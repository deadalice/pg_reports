# frozen_string_literal: true

require "spec_helper"

RSpec.describe "YAML-based Reports" do
  describe "ReportLoader" do
    it "loads YAML definitions" do
      definitions = PgReports::ReportLoader.load_all
      expect(definitions).to be_a(Hash)
    end

    it "loads duplicate_indexes definition" do
      definition = PgReports::ReportLoader.get("indexes", "duplicate_indexes")
      expect(definition).to be_a(PgReports::ReportDefinition)
      expect(definition.config["name"]).to eq("duplicate_indexes")
      expect(definition.config["module"]).to eq("indexes")
    end
  end

  describe "ModuleGenerator" do
    it "generates duplicate_indexes method on Indexes module" do
      expect(PgReports::Modules::Indexes).to respond_to(:duplicate_indexes)
    end
  end

  describe "duplicate_indexes YAML report" do
    let(:mock_connection) do
      double("connection", exec_query: double(to_a: [
        {
          "table_name" => "users",
          "index_name" => "idx_email",
          "duplicate_of" => "idx_email_unique",
          "index_size_mb" => "2.5"
        }
      ]))
    end

    before do
      allow(PgReports.config).to receive(:connection).and_return(mock_connection)
    end

    it "generates a Report object" do
      report = PgReports::Modules::Indexes.duplicate_indexes
      expect(report).to be_a(PgReports::Report)
    end

    it "has correct title" do
      report = PgReports::Modules::Indexes.duplicate_indexes
      expect(report.title).to eq("Duplicate Indexes")
    end

    it "has correct columns" do
      report = PgReports::Modules::Indexes.duplicate_indexes
      expect(report.columns).to eq(%w[table_name index_name duplicate_of index_size_mb])
    end

    it "executes SQL and returns data" do
      report = PgReports::Modules::Indexes.duplicate_indexes
      expect(report.data).not_to be_empty
      expect(report.data.first["table_name"]).to eq("users")
    end
  end

  describe "Filter class" do
    let(:data) do
      [
        { "value" => "10" },
        { "value" => "20" },
        { "value" => "30" }
      ]
    end

    it "filters with lte operator" do
      filter_config = {
        "field" => "value",
        "operator" => "lte",
        "value" => { "source" => "param", "key" => "threshold" },
        "cast" => "integer"
      }

      filter = PgReports::Filter.new(filter_config)
      result = filter.apply(data, { threshold: 20 })

      expect(result.size).to eq(2)
      expect(result.map { |r| r["value"] }).to eq(%w[10 20])
    end

    it "filters with gte operator" do
      filter_config = {
        "field" => "value",
        "operator" => "gte",
        "value" => { "source" => "param", "key" => "threshold" },
        "cast" => "integer"
      }

      filter = PgReports::Filter.new(filter_config)
      result = filter.apply(data, { threshold: 20 })

      expect(result.size).to eq(2)
      expect(result.map { |r| r["value"] }).to eq(%w[20 30])
    end
  end
end
