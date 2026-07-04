# frozen_string_literal: true

require "tmpdir"

RSpec.describe PgReports::Standalone do
  # `apply_configuration` and friends are private (they're internal to `run`),
  # but they carry the config-layering logic, so exercise them directly rather
  # than booting a Rails app + database.
  describe "configuration layering" do
    around do |example|
      Dir.mktmpdir("pg_reports-standalone-spec") do |dir|
        Dir.chdir(dir) { example.run }
      end
    end

    before { PgReports.reset_configuration! }
    after { PgReports.reset_configuration! }

    def apply(config_file: nil, overrides: {})
      described_class.send(:apply_configuration, config_file: config_file, overrides: overrides)
    end

    it "applies CLI overrides and ignores nil ones" do
      PgReports.config.allow_raw_query_execution = false
      PgReports.config.allow_migration_creation = false

      apply(overrides: {allow_raw_query_execution: true, allow_migration_creation: nil})

      expect(PgReports.config.allow_raw_query_execution).to be true
      # nil override left the existing value untouched
      expect(PgReports.config.allow_migration_creation).to be false
    end

    it "loads an explicit config file that calls PgReports.configure" do
      File.write("custom.rb", <<~RUBY)
        PgReports.configure do |c|
          c.allow_raw_query_execution = true
          c.slow_query_threshold_ms = 250
        end
      RUBY

      apply(config_file: "custom.rb")

      expect(PgReports.config.allow_raw_query_execution).to be true
      expect(PgReports.config.slow_query_threshold_ms).to eq(250)
    end

    it "auto-detects ./pg_reports.rb when no config file is given" do
      File.write("pg_reports.rb", "PgReports.config.max_query_length = 999\n")

      apply

      expect(PgReports.config.max_query_length).to eq(999)
    end

    it "lets CLI overrides win over the config file" do
      File.write("pg_reports.rb", "PgReports.config.allow_raw_query_execution = true\n")

      apply(overrides: {allow_raw_query_execution: false})

      expect(PgReports.config.allow_raw_query_execution).to be false
    end

    it "raises a clear error when an explicit config file is missing" do
      expect { apply(config_file: "nope.rb") }
        .to raise_error(PgReports::Error, /Config file not found: nope\.rb/)
    end

    it "wraps errors raised while loading a config file" do
      File.write("pg_reports.rb", "raise 'boom'\n")

      expect { apply }
        .to raise_error(PgReports::Error, /Failed to load config file .*pg_reports\.rb: boom/)
    end

    it "does nothing when no config file exists and no overrides are given" do
      expect { apply }.not_to raise_error
    end
  end
end
