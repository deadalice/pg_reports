# frozen_string_literal: true

require "pg"

RSpec.describe PgReports::Connection::ErrorTranslator do
  describe ".translate" do
    it "translates 'permission denied for database' into a CONNECT GRANT hint" do
      error = build_pg_error("42501", %(permission denied for database "logs"))

      result = described_class.translate(error)

      expect(result[:title]).to eq("Permission denied")
      expect(result[:detail]).to include("database")
      expect(result[:detail]).to include("logs")
      expect(result[:hint]).to include("GRANT CONNECT ON DATABASE logs")
      expect(result[:code]).to eq("42501")
    end

    it "translates 'permission denied for table' into a SELECT GRANT hint" do
      error = build_pg_error("42501", %(permission denied for table "public.users"))

      result = described_class.translate(error)

      expect(result[:hint]).to include("GRANT SELECT ON public.users")
    end

    it "names the extension behind a missing extension-provided relation" do
      error = build_pg_error("42P01", %(relation "pg_stat_statements" does not exist\nLINE 11: FROM pg_stat_statements s))

      result = described_class.translate(error)

      expect(result[:title]).to include("pg_stat_statements")
      expect(result[:detail]).to include("does not exist on the selected database")
      expect(result[:hint]).to eq("CREATE EXTENSION IF NOT EXISTS pg_stat_statements;")
      expect(result[:code]).to eq("42P01")
    end

    it "falls back to a plain message for a missing ordinary relation" do
      error = build_pg_error("42P01", %(relation "widgets" does not exist))

      result = described_class.translate(error)

      expect(result[:title]).to eq("Relation not found")
      expect(result[:detail]).to include("widgets")
      expect(result[:hint]).to be_nil
    end

    it "translates a missing function" do
      error = build_pg_error("42883", %(function pgstattuple(unknown) does not exist))

      result = described_class.translate(error)

      expect(result[:title]).to eq("Function not found")
      expect(result[:detail]).to include("pgstattuple")
    end

    it "translates 'database does not exist'" do
      error = build_pg_error("3D000", %(database "nope" does not exist))

      result = described_class.translate(error)

      expect(result[:title]).to eq("Database not found")
      expect(result[:detail]).to include("nope")
    end

    it "translates auth failures with a remediation hint" do
      error = build_pg_error("28P01", "password authentication failed")

      result = described_class.translate(error)

      expect(result[:title]).to eq("Authentication failed")
      expect(result[:hint]).to be_present
    end

    it "unwraps ActiveRecord::StatementInvalid wrapping a PG::Error" do
      cause = build_pg_error("42501", %(permission denied for database "x"))
      error = ActiveRecord::StatementInvalid.new("wrapped")
      allow(error).to receive(:cause).and_return(cause)

      result = described_class.translate(error)

      expect(result[:code]).to eq("42501")
      expect(result[:title]).to eq("Permission denied")
    end

    it "falls back to a generic message for unknown errors" do
      error = StandardError.new("something else")
      result = described_class.translate(error)

      expect(result[:title]).to eq("StandardError")
      expect(result[:detail]).to eq("something else")
    end
  end

  def build_pg_error(sqlstate, message)
    error = PG::Error.new(message)
    pg_result = double("PG::Result")
    allow(pg_result).to receive(:error_field).with(PG::Result::PG_DIAG_SQLSTATE).and_return(sqlstate)
    allow(error).to receive(:result).and_return(pg_result)
    error
  end
end
