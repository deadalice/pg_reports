# frozen_string_literal: true

RSpec.describe PgReports::Executor do
  describe "lazy connection resolution" do
    it "consults PgReports.config.connection on every call, not at construction" do
      first_conn = double("conn1")
      second_conn = double("conn2")

      first_result = double("result1", to_a: [{"v" => 1}])
      second_result = double("result2", to_a: [{"v" => 2}])

      expect(first_conn).to receive(:exec_query).with("SELECT 1").and_return(first_result)
      expect(second_conn).to receive(:exec_query).with("SELECT 2").and_return(second_result)

      executor = described_class.new

      allow(PgReports.config).to receive(:connection).and_return(first_conn)
      expect(executor.execute("SELECT 1")).to eq([{"v" => 1}])

      allow(PgReports.config).to receive(:connection).and_return(second_conn)
      expect(executor.execute("SELECT 2")).to eq([{"v" => 2}])
    end

    it "honors an explicit connection override over the registry" do
      override = double("override")
      result = double("result", to_a: [])
      expect(override).to receive(:exec_query).with("SELECT 1").and_return(result)
      allow(PgReports.config).to receive(:connection).and_raise("registry should not be hit")

      executor = described_class.new(connection: override)
      executor.execute("SELECT 1")
    end
  end
end
