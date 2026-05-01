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

  describe "Grafana exporter configuration" do
    it "defaults grafana_favorites to an empty array" do
      expect(config.grafana_favorites).to eq([])
    end

    it "defaults grafana_cache_ttl to 60 seconds" do
      expect(config.grafana_cache_ttl).to eq(60)
    end

    it "allows setting favorites as an array" do
      config.grafana_favorites = [:slow_queries, :unused_indexes]
      expect(config.grafana_favorites).to eq([:slow_queries, :unused_indexes])
    end

    it "allows setting favorites as a hash with per-report opts" do
      config.grafana_favorites = {slow_queries: {limit: 20}}
      expect(config.grafana_favorites).to eq({slow_queries: {limit: 20}})
    end

    it "reads PG_REPORTS_METRICS_TOKEN from ENV" do
      ENV["PG_REPORTS_METRICS_TOKEN"] = "secret-token"
      new_config = described_class.new
      expect(new_config.grafana_metrics_token).to eq("secret-token")
    ensure
      ENV.delete("PG_REPORTS_METRICS_TOKEN")
    end
  end

  describe "multi-target configuration" do
    around do |example|
      registry = PgReports.connection_registry
      registry.reset!
      example.run
      registry.reset!
    end

    describe "#add_target" do
      it "registers a new target on the connection registry" do
        config.add_target :analytics, host: "h", database: "warehouse"

        registry = PgReports.connection_registry
        expect(registry.target?(:analytics)).to be true
        expect(registry.fetch(:analytics).default_database).to eq("warehouse")
      end
    end

    describe "#default_target" do
      it "returns the registry's default target name" do
        expect(config.default_target).to eq(:primary)
      end

      it "is settable" do
        config.add_target :analytics, host: "h", database: "warehouse"
        config.default_target = :analytics

        expect(config.default_target).to eq(:analytics)
      end
    end

    describe "#connection" do
      it "returns the legacy @connection_pool override when set" do
        custom_pool = double("custom_connection")
        config.connection_pool = custom_pool

        expect(config.connection).to equal(custom_pool)
      end

      it "delegates to the registry when no legacy override is set" do
        registry = PgReports.connection_registry
        fake_connection = double("ar_connection")
        allow(registry).to receive(:current_connection).and_return(fake_connection)

        config.connection_pool = nil

        expect(config.connection).to equal(fake_connection)
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
