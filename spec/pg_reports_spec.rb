# frozen_string_literal: true

RSpec.describe PgReports do
  describe "VERSION" do
    it "has a version number" do
      expect(PgReports::VERSION).not_to be_nil
      expect(PgReports::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe ".configure" do
    after { PgReports.reset_configuration! }

    it "allows configuration via block" do
      PgReports.configure do |config|
        config.slow_query_threshold_ms = 500
        config.telegram_bot_token = "test_token"
      end

      expect(PgReports.config.slow_query_threshold_ms).to eq(500)
      expect(PgReports.config.telegram_bot_token).to eq("test_token")
    end
  end

  describe ".config" do
    it "returns Configuration instance" do
      expect(PgReports.config).to be_a(PgReports::Configuration)
    end

    it "has default values" do
      config = PgReports.config

      expect(config.slow_query_threshold_ms).to eq(100)
      expect(config.heavy_query_threshold_calls).to eq(1000)
      expect(config.bloat_threshold_percent).to eq(20)
    end
  end

  describe "module accessors" do
    it "provides access to Queries module" do
      expect(PgReports.queries).to eq(PgReports::Modules::Queries)
    end

    it "provides access to Indexes module" do
      expect(PgReports.indexes).to eq(PgReports::Modules::Indexes)
    end

    it "provides access to Tables module" do
      expect(PgReports.tables).to eq(PgReports::Modules::Tables)
    end

    it "provides access to Connections module" do
      expect(PgReports.connections).to eq(PgReports::Modules::Connections)
    end

    it "provides access to System module" do
      expect(PgReports.system).to eq(PgReports::Modules::System)
    end
  end
end
