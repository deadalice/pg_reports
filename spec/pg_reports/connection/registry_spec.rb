# frozen_string_literal: true

RSpec.describe PgReports::Connection::Registry do
  subject(:registry) { described_class.new }

  describe "#default_name" do
    it "defaults to :primary" do
      expect(registry.default_name).to eq(:primary)
    end

    it "is settable, normalizing to a symbol" do
      registry.default_name = "analytics"
      expect(registry.default_name).to eq(:analytics)
    end
  end

  describe "#register" do
    it "creates a Target with normalized symbol name" do
      registry.register("foo", host: "localhost", database: "bar")

      expect(registry.target?(:foo)).to be true
      expect(registry.fetch(:foo)).to be_a(PgReports::Connection::Target)
    end

    it "overwrites an existing target with the same name" do
      registry.register(:foo, host: "h1", database: "db1")
      first = registry.fetch(:foo)

      registry.register(:foo, host: "h2", database: "db2")
      second = registry.fetch(:foo)

      expect(second).not_to equal(first)
      expect(second.spec[:host]).to eq("h2")
    end
  end

  describe "#fetch" do
    it "raises UnknownTarget for missing names" do
      expect { registry.fetch(:nope) }.to raise_error(described_class::UnknownTarget, /nope/)
    end

    it "uses the default name when called with nil" do
      registry.register(:primary, host: "h", database: "db")
      expect(registry.fetch.name).to eq(:primary)
    end
  end

  describe "thread-local context" do
    before do
      registry.register(:primary, host: "h", database: "primary_db")
      registry.register(:other, host: "h", database: "other_db")
    end

    it "with_context overrides the current target inside the block" do
      seen = nil
      registry.with_context(target: :other) { seen = registry.current_name }

      expect(seen).to eq(:other)
      expect(registry.current_name).to be_nil
    end

    it "with_context restores the previous context on exception" do
      Thread.current[described_class::THREAD_KEY_TARGET] = :primary
      begin
        expect {
          registry.with_context(target: :other) { raise "boom" }
        }.to raise_error("boom")

        expect(registry.current_name).to eq(:primary)
      ensure
        Thread.current[described_class::THREAD_KEY_TARGET] = nil
      end
    end

    it "with_context tracks database alongside target" do
      seen_target = nil
      seen_db = nil
      registry.with_context(target: :primary, database: "switched_db") do
        seen_target = registry.current_name
        seen_db = registry.current_database
      end

      expect(seen_target).to eq(:primary)
      expect(seen_db).to eq("switched_db")
    end

    it "with_context clears the database override when switching target without a new database" do
      registry.with_context(database: "outer_db") do
        registry.with_context(target: :other) do
          # Inner block: target switched, database NOT inherited from outer
          # (outer database belonged to the previous target's cluster).
          expect(registry.current_name).to eq(:other)
          expect(registry.current_database).to be_nil
        end
        # After inner block, outer context is restored.
        expect(registry.current_database).to eq("outer_db")
      end
    end

    it "with_context with only database changes leaves target untouched" do
      registry.with_context(target: :other) do
        registry.with_context(database: "audit") do
          expect(registry.current_name).to eq(:other)
          expect(registry.current_database).to eq("audit")
        end
        expect(registry.current_database).to be_nil
      end
    end
  end

  describe "#current_database_name" do
    before { registry.register(:primary, host: "h", database: "default_db") }

    it "returns the target default when no override" do
      expect(registry.current_database_name).to eq("default_db")
    end

    it "returns the override when set" do
      registry.with_context(target: :primary, database: "switched") do
        expect(registry.current_database_name).to eq("switched")
      end
    end
  end

  describe "#ensure_default_registered!" do
    it "is a no-op when ActiveRecord is connected and :primary already exists" do
      registry.register(:primary, host: "h", database: "db")
      expect { registry.ensure_default_registered! }.not_to raise_error
      expect(registry.target_names).to eq([:primary])
    end

    it "auto-registers :primary from ActiveRecord::Base when available" do
      fake_config = double("DbConfig", configuration_hash: {host: "auto", database: "auto_db", adapter: "postgresql"})
      allow(ActiveRecord::Base).to receive(:connection_db_config).and_return(fake_config)

      registry.ensure_default_registered!

      expect(registry.target?(:primary)).to be true
      expect(registry.fetch(:primary).spec[:host]).to eq("auto")
    end

    it "tolerates ActiveRecord not being connected yet" do
      allow(ActiveRecord::Base).to receive(:connection_db_config)
        .and_raise(ActiveRecord::ConnectionNotEstablished)

      expect { registry.ensure_default_registered! }.not_to raise_error
      expect(registry.target?(:primary)).to be false
    end
  end
end
