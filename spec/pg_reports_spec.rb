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

  describe "multi-database helpers" do
    let(:registry) { PgReports.connection_registry }

    around do |example|
      registry.reset!
      registry.register(:primary, host: "h", database: "primary_db")
      registry.register(:secondary, host: "h", database: "secondary_db")
      example.run
      registry.reset!
    end

    describe ".with_target" do
      it "sets thread-local target inside the block, restores after" do
        seen = nil
        PgReports.with_target(:secondary) { seen = registry.current_name }

        expect(seen).to eq(:secondary)
        expect(registry.current_name).to be_nil
      end

      it "accepts an explicit database override" do
        seen_target = nil
        seen_db = nil
        PgReports.with_target(:primary, database: "logs") do
          seen_target = registry.current_name
          seen_db = registry.current_database
        end

        expect(seen_target).to eq(:primary)
        expect(seen_db).to eq("logs")
      end

      it "restores prior context on exception" do
        Thread.current[PgReports::Connection::Registry::THREAD_KEY_TARGET] = :primary

        expect {
          PgReports.with_target(:secondary) { raise "boom" }
        }.to raise_error("boom")

        expect(registry.current_name).to eq(:primary)
      ensure
        Thread.current[PgReports::Connection::Registry::THREAD_KEY_TARGET] = nil
      end
    end

    describe ".with_database" do
      it "swaps database on the currently active target" do
        PgReports.with_target(:secondary) do
          PgReports.with_database("audit_log") do
            expect(registry.current_name).to eq(:secondary)
            expect(registry.current_database).to eq("audit_log")
          end
        end
      end

      it "uses the registry's default target when no target is active" do
        PgReports.with_database("audit_log") do
          expect(registry.current_name).to eq(registry.default_name)
          expect(registry.current_database).to eq("audit_log")
        end
      end
    end

    describe ".current_target_name" do
      it "falls back to the registry default when no target is active" do
        expect(PgReports.current_target_name).to eq(:primary)
      end

      it "returns the active target inside with_target" do
        PgReports.with_target(:secondary) do
          expect(PgReports.current_target_name).to eq(:secondary)
        end
      end
    end

    describe ".current_database_name" do
      it "returns the target's default database when no override is set" do
        expect(PgReports.current_database_name).to eq("primary_db")
      end

      it "returns the override inside with_database" do
        PgReports.with_database("audit") do
          expect(PgReports.current_database_name).to eq("audit")
        end
      end
    end

    describe ".list_targets" do
      it "returns all registered targets with current marker" do
        result = PgReports.list_targets

        primary = result.find { |t| t[:name] == :primary }
        secondary = result.find { |t| t[:name] == :secondary }

        expect(primary).to include(default_database: "primary_db", current: true)
        expect(secondary).to include(default_database: "secondary_db", current: false)
      end

      it "marks the active target inside with_target" do
        PgReports.with_target(:secondary) do
          result = PgReports.list_targets
          expect(result.find { |t| t[:name] == :secondary }[:current]).to be true
          expect(result.find { |t| t[:name] == :primary }[:current]).to be false
        end
      end
    end

    describe ".list_databases" do
      it "delegates to the active target's list_databases" do
        target = registry.fetch(:primary)
        rows = [{"name" => "primary_db", "size" => "8192 kB"}]
        allow(target).to receive(:list_databases).and_return(rows)

        result = PgReports.list_databases

        expect(result).to eq(rows)
      end
    end
  end
end
