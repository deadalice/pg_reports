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
end
