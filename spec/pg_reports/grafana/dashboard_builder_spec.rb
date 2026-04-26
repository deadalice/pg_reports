# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe PgReports::Grafana::DashboardBuilder do
  before { PgReports.reset_configuration! }

  describe ".build" do
    it "raises when no favorites are configured" do
      expect { described_class.build }.to raise_error(ArgumentError, /No favorites configured/)
    end

    context "with a small set of favorites" do
      let(:dashboard) do
        described_class.build(favorites: [:slow_queries, :unused_indexes, :missing_validations])
      end

      it "is serializable JSON" do
        expect { JSON.generate(dashboard) }.not_to raise_error
      end

      it "declares Prometheus as a required input" do
        expect(dashboard["__inputs"]).to contain_exactly(
          a_hash_including("name" => "DS_PROMETHEUS", "pluginId" => "prometheus")
        )
      end

      it "uses the standard Grafana schema version" do
        expect(dashboard["schemaVersion"]).to be >= 38
      end

      it "tags itself for discovery" do
        expect(dashboard["tags"]).to include("pg_reports", "postgresql")
      end

      it "creates one row per used category and 2 panels per favorite (timeseries + table)" do
        rows = dashboard["panels"].select { |p| p["type"] == "row" }
        timeseries = dashboard["panels"].select { |p| p["type"] == "timeseries" }
        tables = dashboard["panels"].select { |p| p["type"] == "table" }

        expect(rows.size).to eq(3) # queries, indexes, schema_analysis
        expect(timeseries.size).to eq(3)
        expect(tables.size).to eq(3)
      end

      it "does not include the legacy stat panel" do
        stats = dashboard["panels"].select { |p| p["type"] == "stat" }
        expect(stats).to be_empty
      end

      it "table panels query pg_reports_row in instant table format" do
        tables = dashboard["panels"].select { |p| p["type"] == "table" }
        tables.each do |panel|
          target = panel["targets"].first
          expect(target["expr"]).to start_with("pg_reports_row{")
          expect(target["instant"]).to be true
          expect(target["format"]).to eq("table")
        end
      end

      it "table panels apply labelsToFields transformation" do
        tables = dashboard["panels"].select { |p| p["type"] == "table" }
        tables.each do |panel|
          ids = panel["transformations"].map { |t| t["id"] }
          expect(ids).to include("labelsToFields")
        end
      end

      it "table panels hide internal Prometheus columns" do
        tables = dashboard["panels"].select { |p| p["type"] == "table" }
        tables.each do |panel|
          organize = panel["transformations"].find { |t| t["id"] == "organize" }
          excluded = organize["options"]["excludeByName"]
          expect(excluded).to include("Time" => true, "__name__" => true, "report" => true, "row" => true)
        end
      end

      it "groups panels by category — row title matches the registry" do
        row_titles = dashboard["panels"].select { |p| p["type"] == "row" }.map { |p| p["title"] }
        expect(row_titles).to include("Queries", "Indexes", "Schema Analysis")
      end

      it "every PromQL target references the report key" do
        keys = %w[slow_queries unused_indexes missing_validations]
        exprs = dashboard["panels"]
          .reject { |p| p["type"] == "row" }
          .flat_map { |p| p["targets"].map { |t| t["expr"] } }

        keys.each do |key|
          expect(exprs).to include(a_string_including(%(report="#{key}")))
        end
      end

      it "timeseries panels emit one target per severity" do
        timeseries = dashboard["panels"].select { |p| p["type"] == "timeseries" }
        timeseries.each do |panel|
          severities = panel["targets"].map { |t| t["legendFormat"] }
          expect(severities).to contain_exactly("ok", "warning", "critical")
        end
      end

      it "wires distinct refIds per target inside a panel" do
        timeseries = dashboard["panels"].select { |p| p["type"] == "timeseries" }
        timeseries.each do |panel|
          refs = panel["targets"].map { |t| t["refId"] }
          expect(refs).to eq(refs.uniq)
        end
      end

      it "assigns unique panel ids" do
        ids = dashboard["panels"].map { |p| p["id"] }
        expect(ids).to eq(ids.uniq)
      end

      it "lays out panels without horizontal overlap inside a row" do
        # Panels at the same y must not overlap in x.
        dashboard["panels"]
          .reject { |p| p["type"] == "row" }
          .group_by { |p| p["gridPos"]["y"] }
          .each_value do |panels|
            sorted = panels.sort_by { |p| p["gridPos"]["x"] }
            sorted.each_cons(2) do |left, right|
              expect(left["gridPos"]["x"] + left["gridPos"]["w"]).to be <= right["gridPos"]["x"]
            end
          end
      end

      it "fits within Grafana's 24-column grid" do
        dashboard["panels"].each do |panel|
          right_edge = panel["gridPos"]["x"] + panel["gridPos"]["w"]
          expect(right_edge).to be <= 24
        end
      end

      it "applies severity colour overrides on timeseries panels" do
        timeseries = dashboard["panels"].select { |p| p["type"] == "timeseries" }
        timeseries.each do |panel|
          overrides = panel["fieldConfig"]["overrides"]
          mapped = overrides.map { |o| o["matcher"]["options"] }
          expect(mapped).to include("ok", "warning", "critical")
        end
      end
    end

    context "favorites normalization" do
      it "accepts a Hash and uses only the keys" do
        dashboard = described_class.build(favorites: {slow_queries: {limit: 10}})
        keys = dashboard["panels"]
          .reject { |p| p["type"] == "row" }
          .flat_map { |p| p["targets"].map { |t| t["expr"] } }
          .grep(/report="(\w+)"/) { Regexp.last_match(1) }

        expect(keys).to all(eq("slow_queries"))
      end

      it "accepts string keys" do
        expect {
          described_class.build(favorites: ["slow_queries"])
        }.not_to raise_error
      end

      it "skips unknown favorite keys silently" do
        dashboard = described_class.build(favorites: [:slow_queries, :nonexistent])
        rows = dashboard["panels"].select { |p| p["type"] == "row" }
        expect(rows.size).to eq(1)
      end
    end

    context "customization" do
      it "respects custom title and uid" do
        dashboard = described_class.build(
          favorites: [:slow_queries],
          title: "My DB",
          uid: "my-db"
        )
        expect(dashboard["title"]).to eq("My DB")
        expect(dashboard["uid"]).to eq("my-db")
      end

      it "respects custom refresh interval and time range" do
        dashboard = described_class.build(
          favorites: [:slow_queries],
          refresh: "30s",
          time_from: "now-24h"
        )
        expect(dashboard["refresh"]).to eq("30s")
        expect(dashboard["time"]).to eq({"from" => "now-24h", "to" => "now"})
      end
    end

    context "reads from PgReports.config.grafana_favorites" do
      it "uses the configured favorites when none are passed" do
        PgReports.config.grafana_favorites = [:slow_queries]
        dashboard = described_class.build
        rows = dashboard["panels"].select { |p| p["type"] == "row" }

        expect(rows.size).to eq(1)
      end
    end
  end
end
