# frozen_string_literal: true

RSpec.describe PgReports::Configuration do
  subject(:config) { described_class.new }

  describe "#initialize" do
    it "sets default query thresholds" do
      expect(config.slow_query_threshold_ms).to eq(100)
      expect(config.heavy_query_threshold_calls).to eq(1000)
      expect(config.expensive_query_threshold_ms).to eq(10_000)
    end

    it "sets default index thresholds" do
      expect(config.unused_index_threshold_scans).to eq(50)
    end

    it "sets default table thresholds" do
      expect(config.bloat_threshold_percent).to eq(20)
      expect(config.dead_rows_threshold).to eq(10_000)
    end

    it "sets default output settings" do
      expect(config.max_query_length).to eq(200)
    end
  end

  describe "#telegram_configured?" do
    it "returns false when token is missing" do
      config.telegram_bot_token = nil
      config.telegram_chat_id = "123"

      expect(config.telegram_configured?).to be false
    end

    it "returns false when chat_id is missing" do
      config.telegram_bot_token = "token"
      config.telegram_chat_id = nil

      expect(config.telegram_configured?).to be false
    end

    it "returns true when both are present" do
      config.telegram_bot_token = "token"
      config.telegram_chat_id = "123"

      expect(config.telegram_configured?).to be true
    end
  end
end
