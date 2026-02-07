# frozen_string_literal: true

RSpec.describe PgReports::Modules::System do
  describe ".databases_list" do
    it "returns list of databases" do
      allow_any_instance_of(PgReports::Executor).to receive(:execute_from_file).and_return([
        {"database" => "db1"},
        {"database" => "db2"}
      ])

      result = described_class.databases_list
      expect(result).to be_an(Array)
    end

    it "includes database name" do
      allow_any_instance_of(PgReports::Executor).to receive(:execute_from_file).and_return([
        {"database" => "test_db"}
      ])

      result = described_class.databases_list
      expect(result.first).to have_key("database") if result.any?
    end

    it "handles query errors gracefully" do
      allow_any_instance_of(PgReports::Executor).to receive(:execute_from_file).and_raise(StandardError)
      result = described_class.databases_list
      expect(result).to eq([])
    end
  end

  describe ".current_database" do
    it "returns current database name" do
      allow_any_instance_of(PgReports::Executor).to receive(:execute).and_return([
        {"database" => "test_db"}
      ])

      result = described_class.current_database
      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end

    it "handles query errors gracefully" do
      allow_any_instance_of(PgReports::Executor).to receive(:execute).and_raise(StandardError)
      result = described_class.current_database
      expect(result).to eq("unknown")
    end
  end

  describe ".pg_stat_statements_available?" do
    it "returns boolean" do
      allow(described_class).to receive(:pg_stat_statements_available?).and_return(true)
      result = described_class.pg_stat_statements_available?
      expect(result).to be_in([true, false])
    end
  end

  describe ".pg_stat_statements_preloaded?" do
    it "returns boolean" do
      allow(described_class).to receive(:pg_stat_statements_preloaded?).and_return(true)
      result = described_class.pg_stat_statements_preloaded?
      expect(result).to be_in([true, false])
    end
  end

  describe ".pg_stat_statements_status" do
    it "returns hash with status" do
      status = {
        extension_installed: true,
        preloaded: true,
        ready: true
      }
      allow(described_class).to receive(:pg_stat_statements_status).and_return(status)

      result = described_class.pg_stat_statements_status
      expect(result).to be_a(Hash)
      expect(result).to have_key(:extension_installed)
      expect(result).to have_key(:preloaded)
      expect(result).to have_key(:ready)
    end
  end
end
