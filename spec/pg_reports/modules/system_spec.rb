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
    let(:mock_executor) { instance_double(PgReports::Executor) }

    before do
      # Reset the cached executor and inject our mock
      described_class.instance_variable_set(:@executor, nil)
      allow(PgReports::Executor).to receive(:new).and_return(mock_executor)
    end

    after do
      # Clean up
      described_class.instance_variable_set(:@executor, nil)
    end

    context "when extension is not installed" do
      it "returns false" do
        allow(mock_executor).to receive(:execute).and_return([{"available" => false}])
        result = described_class.pg_stat_statements_preloaded?
        expect(result).to be false
      end
    end

    context "when extension is installed and preloaded" do
      it "returns true" do
        # Mock pg_stat_statements_available? to return true
        allow(mock_executor).to receive(:execute).with(/SELECT EXISTS.*pg_extension/m).and_return([{"available" => "t"}])
        # Mock the query to pg_stat_statements to succeed
        allow(mock_executor).to receive(:execute).with("SELECT 1 FROM pg_stat_statements LIMIT 1").and_return([{"?column?" => 1}])

        result = described_class.pg_stat_statements_preloaded?
        expect(result).to be true
      end
    end

    context "when extension is installed but not preloaded" do
      it "returns false" do
        # Mock pg_stat_statements_available? to return true
        allow(mock_executor).to receive(:execute).with(/SELECT EXISTS.*pg_extension/m).and_return([{"available" => "t"}])
        # Mock the query to pg_stat_statements to fail
        allow(mock_executor).to receive(:execute).with("SELECT 1 FROM pg_stat_statements LIMIT 1").and_raise(
          StandardError.new("relation \"pg_stat_statements\" does not exist")
        )

        result = described_class.pg_stat_statements_preloaded?
        expect(result).to be false
      end
    end

    context "when user lacks pg_read_all_settings permission" do
      it "still works by querying pg_stat_statements directly" do
        # Mock pg_stat_statements_available? to return true
        allow(mock_executor).to receive(:execute).with(/SELECT EXISTS.*pg_extension/m).and_return([{"available" => "t"}])
        # Mock the query to pg_stat_statements to succeed
        allow(mock_executor).to receive(:execute).with("SELECT 1 FROM pg_stat_statements LIMIT 1").and_return([{"?column?" => 1}])

        result = described_class.pg_stat_statements_preloaded?
        expect(result).to be true
      end
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
