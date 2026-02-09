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

    it "sets default query monitoring settings" do
      expect(config.query_monitor_max_queries).to eq(100)
      expect(config.query_monitor_backtrace_filter).to be_a(Proc)
    end

    it "sets default security settings" do
      expect(config.allow_raw_query_execution).to be false
    end
  end

  describe "query monitoring configuration" do
    it "allows setting custom log file path" do
      custom_path = "/tmp/custom_pg_reports.log"
      config.query_monitor_log_file = custom_path

      expect(config.query_monitor_log_file).to eq(custom_path)
    end

    it "allows setting max queries buffer size" do
      config.query_monitor_max_queries = 200

      expect(config.query_monitor_max_queries).to eq(200)
    end

    it "allows setting custom backtrace filter" do
      custom_filter = ->(location) { true }
      config.query_monitor_backtrace_filter = custom_filter

      expect(config.query_monitor_backtrace_filter).to eq(custom_filter)
    end

    it "backtrace filter excludes gem paths by default" do
      location = double("Location", path: "/usr/local/bundle/gems/activerecord/lib/active_record.rb")

      expect(config.query_monitor_backtrace_filter.call(location)).to be false
    end

    it "backtrace filter excludes ruby paths by default" do
      location = double("Location", path: "/usr/local/lib/ruby/3.2.0/monitor.rb")

      expect(config.query_monitor_backtrace_filter.call(location)).to be false
    end

    it "backtrace filter includes application paths by default" do
      location = double("Location", path: "/app/controllers/users_controller.rb")

      expect(config.query_monitor_backtrace_filter.call(location)).to be true
    end
  end

  describe "#allow_raw_query_execution" do
    it "can be set to true" do
      config.allow_raw_query_execution = true
      expect(config.allow_raw_query_execution).to be true
    end

    it "can be set to false" do
      config.allow_raw_query_execution = false
      expect(config.allow_raw_query_execution).to be false
    end

    context "when reading from ENV" do
      after do
        ENV.delete("PG_REPORTS_ALLOW_RAW_QUERY_EXECUTION")
      end

      it "reads PG_REPORTS_ALLOW_RAW_QUERY_EXECUTION=true" do
        ENV["PG_REPORTS_ALLOW_RAW_QUERY_EXECUTION"] = "true"
        new_config = described_class.new
        expect(new_config.allow_raw_query_execution).to be true
      end

      it "reads PG_REPORTS_ALLOW_RAW_QUERY_EXECUTION=false" do
        ENV["PG_REPORTS_ALLOW_RAW_QUERY_EXECUTION"] = "false"
        new_config = described_class.new
        expect(new_config.allow_raw_query_execution).to be false
      end

      it "defaults to false when ENV variable not set" do
        ENV.delete("PG_REPORTS_ALLOW_RAW_QUERY_EXECUTION")
        new_config = described_class.new
        expect(new_config.allow_raw_query_execution).to be false
      end
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
