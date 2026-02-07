# frozen_string_literal: true

require "securerandom"

RSpec.describe PgReports::QueryMonitor do
  let(:monitor) { described_class.instance }

  before do
    # Reset singleton state before each test
    monitor.stop if monitor.enabled
    # Clear queries array
    monitor.instance_variable_set(:@queries, [])
    allow(PgReports.config).to receive(:query_monitor_log_file).and_return(nil)
    allow(PgReports.config).to receive(:query_monitor_max_queries).and_return(100)
    # Disable pg_reports filtering in tests by default (can be overridden in specific tests)
    allow_any_instance_of(PgReports::QueryMonitor).to receive(:query_from_pg_reports?).and_return(false)
  end

  after do
    # Ensure monitoring is stopped after each test
    monitor.stop if monitor.enabled
    # Clear queries array
    monitor.instance_variable_set(:@queries, [])
  end

  describe "#start" do
    it "enables monitoring" do
      result = monitor.start
      expect(result[:success]).to be true
      expect(monitor.enabled).to be true
      expect(monitor.session_id).to be_present
    end

    it "generates a unique session ID" do
      result = monitor.start
      session_id = result[:session_id]

      expect(session_id).to be_present
      expect(session_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it "returns error when already active" do
      monitor.start
      result = monitor.start

      expect(result[:success]).to be false
      expect(result[:message]).to eq("Monitoring already active")
    end

    it "subscribes to sql.active_record events" do
      expect(ActiveSupport::Notifications).to receive(:subscribe).with("sql.active_record")
      monitor.start
    end
  end

  describe "#stop" do
    before { monitor.start }

    it "disables monitoring" do
      result = monitor.stop
      expect(result[:success]).to be true
      expect(monitor.enabled).to be false
    end

    it "unsubscribes from notifications" do
      expect(ActiveSupport::Notifications).to receive(:unsubscribe)
      monitor.stop
    end

    it "clears session_id" do
      monitor.stop
      expect(monitor.session_id).to be_nil
    end

    it "returns error when not active" do
      monitor.stop
      result = monitor.stop

      expect(result[:success]).to be false
      expect(result[:message]).to eq("Monitoring not active")
    end
  end

  describe "#status" do
    context "when monitoring is disabled" do
      it "returns correct status" do
        status = monitor.status

        expect(status[:enabled]).to be false
        expect(status[:session_id]).to be_nil
        expect(status[:query_count]).to eq(0)
      end
    end

    context "when monitoring is enabled" do
      before { monitor.start }

      it "returns correct status" do
        status = monitor.status

        expect(status[:enabled]).to be true
        expect(status[:session_id]).to be_present
        expect(status[:query_count]).to eq(0)
      end
    end
  end

  describe "#queries" do
    before { monitor.start }

    it "returns empty array when no queries captured" do
      expect(monitor.queries).to eq([])
    end

    it "limits results when limit parameter provided" do
      # Simulate adding queries
      10.times { simulate_query("SELECT 1") }

      result = monitor.queries(limit: 5)
      expect(result.size).to eq(5)
    end

    it "filters by session_id when provided" do
      current_session = monitor.session_id
      other_session = "other-session-id"

      # Add query with current session
      simulate_query("SELECT 1")

      # Manually add query with different session (for testing)
      queries = monitor.queries
      queries << {session_id: other_session, sql: "SELECT 2"}

      result = monitor.queries(session_id: current_session)
      expect(result.all? { |q| q[:session_id] == current_session }).to be true
    end
  end

  describe "query filtering" do
    before do
      monitor.stop if monitor.enabled
      monitor.start
    end

    # Clear queries before each test in this block
    before(:each) do
      monitor.instance_variable_set(:@queries, [])
    end

    it "filters out PgReports queries by name" do
      simulate_query("SELECT 1", name: "PgReports Query")
      expect(monitor.queries.size).to eq(0)
    end

    it "filters out queries from pg_reports gem path" do
      # Mock caller_locations to simulate call from pg_reports gem
      allow_any_instance_of(PgReports::QueryMonitor).to receive(:query_from_pg_reports?).and_return(true)
      simulate_query("SELECT 1")
      expect(monitor.queries.size).to eq(0)
    end

    it "filters out SCHEMA queries" do
      simulate_query("CREATE TABLE test", name: "SCHEMA")
      expect(monitor.queries.size).to eq(0)
    end

    it "filters out CACHE queries" do
      simulate_query("SELECT 1", name: "CACHE")
      expect(monitor.queries.size).to eq(0)
    end

    it "filters out cached queries" do
      simulate_query("SELECT 1", cached: true)
      expect(monitor.queries.size).to eq(0)
    end

    it "filters out EXPLAIN queries" do
      simulate_query("EXPLAIN SELECT 1")
      expect(monitor.queries.size).to eq(0)
    end

    it "filters out DDL statements" do
      simulate_query("CREATE INDEX idx ON users(email)")
      simulate_query("ALTER TABLE users ADD COLUMN name VARCHAR")
      simulate_query("DROP TABLE temp")

      expect(monitor.queries.size).to eq(0)
    end

    it "captures regular SELECT queries" do
      simulate_query("SELECT * FROM users")
      expect(monitor.queries.size).to be >= 1
      expect(monitor.queries.last[:sql]).to eq("SELECT * FROM users")
    end

    it "captures INSERT queries" do
      simulate_query("INSERT INTO users (name) VALUES ('test')")
      expect(monitor.queries.size).to be >= 1
      expect(monitor.queries.last[:sql]).to eq("INSERT INTO users (name) VALUES ('test')")
    end

    it "captures UPDATE queries" do
      simulate_query("UPDATE users SET name = 'test'")
      expect(monitor.queries.size).to be >= 1
      expect(monitor.queries.last[:sql]).to eq("UPDATE users SET name = 'test'")
    end

    it "captures DELETE queries" do
      simulate_query("DELETE FROM users WHERE id = 1")
      expect(monitor.queries.size).to be >= 1
      expect(monitor.queries.last[:sql]).to eq("DELETE FROM users WHERE id = 1")
    end
  end

  describe "buffer rotation" do
    before do
      allow(PgReports.config).to receive(:query_monitor_max_queries).and_return(5)
      monitor.start
    end

    it "keeps only last N queries" do
      10.times { |i| simulate_query("SELECT #{i}") }

      expect(monitor.queries.size).to eq(5)
    end

    it "removes oldest queries first" do
      10.times { |i| simulate_query("SELECT #{i}") }

      queries = monitor.queries
      # Should not exceed max_queries limit
      expect(queries.size).to be <= 5

      # Should have newer queries (8, 9) but not oldest ones (0, 1)
      sql_texts = queries.map { |q| q[:sql] }
      expect(sql_texts).to include("SELECT 8").or include("SELECT 9")
      expect(sql_texts).not_to include("SELECT 0", "SELECT 1")
    end
  end

  describe "query capture" do
    before { monitor.start }

    it "captures SQL text" do
      simulate_query("SELECT * FROM users WHERE id = 1")

      query = monitor.queries.first
      expect(query[:sql]).to eq("SELECT * FROM users WHERE id = 1")
    end

    it "captures duration in milliseconds" do
      simulate_query("SELECT 1", duration: 0.050) # 50ms

      query = monitor.queries.first
      expect(query[:duration_ms]).to be_within(5).of(50) # Allow 5ms tolerance
    end

    it "captures query name" do
      simulate_query("SELECT 1", name: "User Load")

      query = monitor.queries.first
      expect(query[:name]).to eq("User Load")
    end

    it "captures timestamp" do
      simulate_query("SELECT 1")

      query = monitor.queries.first
      expect(query[:timestamp]).to be_present
      expect { Time.iso8601(query[:timestamp]) }.not_to raise_error
    end

    it "includes session_id" do
      session_id = monitor.session_id
      simulate_query("SELECT 1")

      query = monitor.queries.first
      expect(query[:session_id]).to eq(session_id)
    end

    it "sets type to 'query'" do
      simulate_query("SELECT 1")

      query = monitor.queries.first
      expect(query[:type]).to eq("query")
    end
  end

  describe "source location extraction" do
    before do
      allow(PgReports.config).to receive(:query_monitor_backtrace_filter).and_return(
        ->(location) { !location.path.match?(%r{/spec/}) }
      )
      monitor.start
    end

    it "extracts source location" do
      simulate_query("SELECT 1")

      query = monitor.queries.first
      expect(query[:source_location]).to be_present
    end

    it "includes file path" do
      simulate_query("SELECT 1")

      query = monitor.queries.first
      expect(query[:source_location][:file]).to be_present
    end

    it "includes line number" do
      simulate_query("SELECT 1")

      query = monitor.queries.first
      expect(query[:source_location][:line]).to be_a(Integer)
    end

    it "includes method name" do
      simulate_query("SELECT 1")

      query = monitor.queries.first
      expect(query[:source_location][:method]).to be_present
    end
  end

  describe "file logging" do
    let(:log_file) { Tempfile.new(["pg_reports_test", ".log"]) }

    before do
      allow(PgReports.config).to receive(:query_monitor_log_file).and_return(log_file.path)
    end

    after do
      log_file.close
      log_file.unlink
    end

    it "writes session start marker" do
      monitor.start
      log_file.rewind

      line = log_file.readline
      data = JSON.parse(line)

      expect(data["type"]).to eq("session_start")
      expect(data["session_id"]).to be_present
    end

    it "writes session end marker" do
      monitor.start
      monitor.stop
      log_file.rewind

      lines = log_file.readlines
      last_line = JSON.parse(lines.last)

      expect(last_line["type"]).to eq("session_end")
    end

    it "flushes queries to file on stop" do
      monitor.start
      # Clear any existing queries from previous operations
      monitor.instance_variable_set(:@queries, [])

      simulate_query("SELECT 1")

      # Wait a moment for async processing
      sleep 0.01

      monitor.stop
      log_file.rewind

      lines = log_file.readlines
      query_lines = lines.select { |l| JSON.parse(l)["type"] == "query" }

      # Should have at least 1 query (may have more due to internal operations)
      expect(query_lines.size).to be >= 1
      # Check that our query is in there
      query_sqls = query_lines.map { |l| JSON.parse(l)["sql"] }
      expect(query_sqls).to include("SELECT 1")
    end
  end

  # Helper method to simulate SQL query notification
  def simulate_query(sql, name: "SQL", duration: 0.01, cached: false)
    # Clear any previous queries from this test
    # (to avoid interference between tests)

    started = Time.now.to_f
    finished = started + duration
    unique_id = SecureRandom.hex(10)

    payload = {
      sql: sql,
      name: name,
      cached: cached,
      binds: [],
      type_casted_binds: [],
      statement_name: nil,
      connection: double("connection")
    }

    # Manually call the notification callback since we're bypassing instrument
    ActiveSupport::Notifications.publish(
      "sql.active_record",
      started,
      finished,
      unique_id,
      payload
    )

    # Give it a tiny moment to process
    sleep 0.001
  end
end
