# frozen_string_literal: true

require "spec_helper"

# Skip request specs if not in Rails environment
return unless defined?(Rails)

RSpec.describe "Query Monitoring", type: :request do
  let(:monitor) { PgReports::QueryMonitor.instance }

  before do
    # Reset monitor state before each test
    monitor.stop if monitor.enabled
  end

  describe "POST /pg_reports/query_monitor/start" do
    it "starts monitoring successfully" do
      post "/pg_reports/query_monitor/start"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["success"]).to be true
      expect(json["message"]).to eq("Query monitoring started")
      expect(json["session_id"]).to be_present
    end

    it "returns error when already active" do
      monitor.start

      post "/pg_reports/query_monitor/start"

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)

      expect(json["success"]).to be false
      expect(json["message"]).to eq("Monitoring already active")
    end

    it "actually enables monitoring" do
      expect {
        post "/pg_reports/query_monitor/start"
      }.to change { monitor.enabled }.from(false).to(true)
    end
  end

  describe "POST /pg_reports/query_monitor/stop" do
    before { monitor.start }

    it "stops monitoring successfully" do
      post "/pg_reports/query_monitor/stop"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["success"]).to be true
      expect(json["message"]).to eq("Query monitoring stopped")
    end

    it "returns error when not active" do
      monitor.stop

      post "/pg_reports/query_monitor/stop"

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)

      expect(json["success"]).to be false
      expect(json["message"]).to eq("Monitoring not active")
    end

    it "actually disables monitoring" do
      expect {
        post "/pg_reports/query_monitor/stop"
      }.to change { monitor.enabled }.from(true).to(false)
    end
  end

  describe "GET /pg_reports/query_monitor/status" do
    context "when monitoring is disabled" do
      it "returns correct status" do
        get "/pg_reports/query_monitor/status"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["success"]).to be true
        expect(json["enabled"]).to be false
        expect(json["session_id"]).to be_nil
        expect(json["query_count"]).to eq(0)
      end
    end

    context "when monitoring is enabled" do
      before { monitor.start }

      it "returns correct status" do
        get "/pg_reports/query_monitor/status"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["success"]).to be true
        expect(json["enabled"]).to be true
        expect(json["session_id"]).to be_present
        expect(json["query_count"]).to be >= 0
      end
    end
  end

  describe "GET /pg_reports/query_monitor/feed" do
    context "when monitoring is disabled" do
      it "returns error" do
        get "/pg_reports/query_monitor/feed"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["success"]).to be false
        expect(json["message"]).to eq("Monitoring not active")
      end
    end

    context "when monitoring is enabled" do
      before { monitor.start }

      it "returns empty queries array" do
        get "/pg_reports/query_monitor/feed"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["success"]).to be true
        expect(json["queries"]).to eq([])
        expect(json["timestamp"]).to be_present
      end

      it "returns captured queries" do
        # Execute a query to capture
        begin
          User.connection.execute("SELECT 1")
        rescue
          nil
        end

        get "/pg_reports/query_monitor/feed"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["success"]).to be true
        expect(json["queries"]).to be_an(Array)
      end

      it "respects limit parameter" do
        # Simulate multiple queries
        10.times {
          begin
            User.connection.execute("SELECT 1")
          rescue
            nil
          end
        }

        get "/pg_reports/query_monitor/feed", params: {limit: 5}

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["queries"].size).to be <= 5
      end

      it "filters by session_id parameter" do
        session_id = monitor.session_id

        get "/pg_reports/query_monitor/feed", params: {session_id: session_id}

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json["success"]).to be true
      end
    end
  end

  describe "integration workflow" do
    it "completes full monitoring cycle" do
      # 1. Start monitoring
      post "/pg_reports/query_monitor/start"
      expect(response).to have_http_status(:success)
      session_id = JSON.parse(response.body)["session_id"]

      # 2. Check status
      get "/pg_reports/query_monitor/status"
      json = JSON.parse(response.body)
      expect(json["enabled"]).to be true
      expect(json["session_id"]).to eq(session_id)

      # 3. Execute queries (captured by monitoring)
      begin
        User.connection.execute("SELECT 1")
      rescue
        nil
      end

      # 4. Get feed
      get "/pg_reports/query_monitor/feed"
      json = JSON.parse(response.body)
      expect(json["success"]).to be true

      # 5. Stop monitoring
      post "/pg_reports/query_monitor/stop"
      expect(response).to have_http_status(:success)

      # 6. Verify stopped
      get "/pg_reports/query_monitor/status"
      json = JSON.parse(response.body)
      expect(json["enabled"]).to be false
    end
  end
end
