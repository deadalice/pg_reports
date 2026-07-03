# frozen_string_literal: true

RSpec.describe PgReports::Connection::Target do
  describe "#initialize" do
    it "normalizes string keys to symbols" do
      target = described_class.new(:foo, "host" => "h", "database" => "d")
      expect(target.spec[:host]).to eq("h")
      expect(target.spec[:database]).to eq("d")
    end

    it "defaults adapter to postgresql" do
      target = described_class.new(:foo, host: "h", database: "d")
      expect(target.spec[:adapter]).to eq("postgresql")
    end

    it "accepts ActiveRecord HashConfig" do
      require "active_record/database_configurations"
      ar_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
        "test", "primary", {host: "h", database: "d", adapter: "postgresql"}
      )
      target = described_class.new(:foo, ar_config)
      expect(target.spec[:host]).to eq("h")
    end
  end

  describe "#default_database" do
    it "returns the configured database as a string" do
      target = described_class.new(:foo, host: "h", database: "mydb")
      expect(target.default_database).to eq("mydb")
    end

    it "returns nil when not configured" do
      target = described_class.new(:foo, host: "h")
      expect(target.default_database).to be_nil
    end
  end

  describe "#ar_class_for" do
    it "raises when no database is given and target has no default" do
      target = described_class.new(:foo, host: "h")
      expect { target.ar_class_for }.to raise_error(ArgumentError, /no default database/)
    end

    it "returns ActiveRecord::Base for primary target's default database" do
      target = described_class.new(:primary, host: "h", database: "primary_db")
      expect(target.ar_class_for("primary_db")).to equal(ActiveRecord::Base)
    end

    it "memoizes per-database" do
      target = described_class.new(:primary, host: "h", database: "primary_db")
      first = target.ar_class_for("primary_db")
      second = target.ar_class_for("primary_db")
      expect(first).to equal(second)
    end
  end

  describe "#list_databases" do
    let(:target) { described_class.new(:primary, host: "h", database: "primary_db") }
    let(:fake_connection) { double("ar_connection") }
    let(:rows) {
      [
        {"name" => "myapp", "size" => "8192 kB"},
        {"name" => "logs", "size" => "16 MB"},
        {"name" => "primary_db", "size" => "2048 kB"}
      ]
    }
    let(:fake_result) { double("result", to_a: rows.map(&:dup)) }

    before do
      allow(target).to receive(:connection_for).and_return(fake_connection)
      allow(fake_connection).to receive(:exec_query).and_return(fake_result)
    end

    it "queries pg_database, excluding templates and no-connect databases" do
      target.list_databases

      expect(fake_connection).to have_received(:exec_query).with(
        a_string_matching(/FROM pg_database\s+WHERE datistemplate = false AND datallowconn = true/),
        "PgReports"
      )
    end

    it "annotates each row with current: true on the matching database" do
      result = target.list_databases(current: "primary_db")

      expect(result.find { |r| r["name"] == "primary_db" }).to include("current" => true)
      expect(result.find { |r| r["name"] == "myapp" }).to include("current" => false)
      expect(result.find { |r| r["name"] == "logs" }).to include("current" => false)
    end

    it "uses the target's default database when no current is given" do
      result = target.list_databases

      expect(result.find { |r| r["name"] == "primary_db" }["current"]).to be true
    end
  end
end
