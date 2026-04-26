# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgReports::Grafana::Exporter do
  def fake_report(rows)
    PgReports::Report.new(title: "fake", data: rows, columns: rows.first&.keys || [])
  end

  before do
    PgReports.reset_configuration!
  end

  describe "#render" do
    context "when there are no favorites" do
      it "produces an empty payload" do
        expect(described_class.render).to eq("")
      end
    end

    context "with a report that has no thresholds" do
      let(:rows) { [{"a" => 1}, {"a" => 2}, {"a" => 3}] }

      before do
        PgReports.config.grafana_favorites = [:row_counts]
        allow(PgReports::Modules::Tables).to receive(:row_counts).and_return(fake_report(rows))
      end

      it "counts every row as ok" do
        output = described_class.render

        expect(output).to include('pg_reports_issues{report="row_counts",severity="ok"} 3')
        expect(output).to include('pg_reports_rows{report="row_counts"} 3')
      end

      it "marks the report as up" do
        expect(described_class.render).to include('pg_reports_up{report="row_counts"} 1')
      end

      it "emits HELP and TYPE lines once per metric name" do
        output = described_class.render

        expect(output.scan("# TYPE pg_reports_issues gauge").size).to eq(1)
        expect(output.scan("# TYPE pg_reports_rows gauge").size).to eq(1)
        expect(output.scan("# TYPE pg_reports_up gauge").size).to eq(1)
      end
    end

    context "with thresholded reports (warning/critical)" do
      let(:rows) do
        [
          {"mean_time_ms" => 50},   # ok
          {"mean_time_ms" => 200},  # warning (>=100)
          {"mean_time_ms" => 600},  # critical (>=500)
          {"mean_time_ms" => 700}   # critical
        ]
      end

      before do
        PgReports.config.grafana_favorites = [:slow_queries]
        allow(PgReports::Modules::Queries).to receive(:slow_queries).and_return(fake_report(rows))
      end

      it "classifies each row by the registry thresholds" do
        output = described_class.render

        expect(output).to include('pg_reports_issues{report="slow_queries",severity="ok"} 1')
        expect(output).to include('pg_reports_issues{report="slow_queries",severity="warning"} 1')
        expect(output).to include('pg_reports_issues{report="slow_queries",severity="critical"} 2')
      end
    end

    context "with inverted thresholds (lower is worse)" do
      let(:rows) do
        [
          {"cache_hit_ratio" => 0.99},  # ok
          {"cache_hit_ratio" => 0.92},  # warning (<=0.95)
          {"cache_hit_ratio" => 0.50}   # critical (<=0.80)
        ]
      end

      before do
        PgReports.config.grafana_favorites = [:low_cache_hit_queries]
        allow(PgReports::Modules::Queries).to receive(:low_cache_hit_queries).and_return(fake_report(rows))
      end

      it "treats low values as worse" do
        output = described_class.render

        expect(output).to include('pg_reports_issues{report="low_cache_hit_queries",severity="ok"} 1')
        expect(output).to include('pg_reports_issues{report="low_cache_hit_queries",severity="warning"} 1')
        expect(output).to include('pg_reports_issues{report="low_cache_hit_queries",severity="critical"} 1')
      end
    end

    context "when severity is computed across multiple thresholded fields" do
      let(:rows) do
        # update_hotspots: updates_per_row >=10 warn, >=100 crit;
        # hot_update_pct <=50 warn, <=20 crit (inverted)
        [
          {"updates_per_row" => 5, "hot_update_pct" => 80},     # ok / ok => ok
          {"updates_per_row" => 50, "hot_update_pct" => 80},    # warn / ok => warn
          {"updates_per_row" => 5, "hot_update_pct" => 10}      # ok / crit => crit
        ]
      end

      before do
        PgReports.config.grafana_favorites = [:update_hotspots]
        allow(PgReports::Modules::Tables).to receive(:update_hotspots).and_return(fake_report(rows))
      end

      it "picks the worst severity across fields" do
        output = described_class.render

        expect(output).to include('pg_reports_issues{report="update_hotspots",severity="ok"} 1')
        expect(output).to include('pg_reports_issues{report="update_hotspots",severity="warning"} 1')
        expect(output).to include('pg_reports_issues{report="update_hotspots",severity="critical"} 1')
      end
    end

    context "when a report raises" do
      before do
        PgReports.config.grafana_favorites = [:slow_queries]
        allow(PgReports::Modules::Queries).to receive(:slow_queries).and_raise(StandardError, "boom")
      end

      it "marks the report as down without aborting the whole payload" do
        output = described_class.render

        expect(output).to include('pg_reports_up{report="slow_queries",error="StandardError"} 0')
        expect(output).not_to include('pg_reports_rows{report="slow_queries"}')
      end

      it "still serves siblings" do
        PgReports.config.grafana_favorites = [:slow_queries, :row_counts]
        allow(PgReports::Modules::Tables).to receive(:row_counts).and_return(fake_report([{"a" => 1}]))

        output = described_class.render

        expect(output).to include('pg_reports_up{report="slow_queries",error="StandardError"} 0')
        expect(output).to include('pg_reports_up{report="row_counts"} 1')
      end
    end

    context "when a report key is unknown" do
      before do
        PgReports.config.grafana_favorites = [:nonexistent_report]
      end

      it "marks it as down with ArgumentError" do
        output = described_class.render

        expect(output).to include('pg_reports_up{report="nonexistent_report",error="ArgumentError"} 0')
      end
    end

    context "favorites normalization" do
      it "accepts a Hash with per-report opts" do
        PgReports.config.grafana_favorites = {slow_queries: {limit: 5}}
        allow(PgReports::Modules::Queries).to receive(:slow_queries).with(limit: 5).and_return(fake_report([]))

        described_class.render

        expect(PgReports::Modules::Queries).to have_received(:slow_queries).with(limit: 5)
      end

      it "accepts string keys" do
        PgReports.config.grafana_favorites = ["slow_queries"]
        allow(PgReports::Modules::Queries).to receive(:slow_queries).and_return(fake_report([]))

        expect { described_class.render }.not_to raise_error
        expect(PgReports::Modules::Queries).to have_received(:slow_queries).with(no_args)
      end
    end

    context "per-row pg_reports_row metric" do
      let(:rows) do
        [
          {"index_name" => "idx_users_email", "schemaname" => "public", "table_name" => "users", "idx_scan" => 0},
          {"index_name" => "idx_orders_uuid", "schemaname" => "public", "table_name" => "orders", "idx_scan" => 3}
        ]
      end

      before do
        PgReports.config.grafana_favorites = [:unused_indexes]
        allow(PgReports::Modules::Indexes).to receive(:unused_indexes).and_return(fake_report(rows))
      end

      it "emits one series per row with row columns as labels" do
        output = described_class.render

        expect(output).to include("pg_reports_row{")
        expect(output).to include('index_name="idx_users_email"')
        expect(output).to include('index_name="idx_orders_uuid"')
        expect(output).to include('table_name="users"')
        expect(output).to include('schemaname="public"')
      end

      it "tags each row with its report and row index" do
        output = described_class.render

        expect(output).to match(/pg_reports_row\{[^}]*report="unused_indexes"[^}]*row="0"[^}]*\} 1/)
        expect(output).to match(/pg_reports_row\{[^}]*report="unused_indexes"[^}]*row="1"[^}]*\} 1/)
      end

      it "skips rows entirely when expose_rows: false" do
        PgReports.config.grafana_favorites = {unused_indexes: {expose_rows: false}}

        output = described_class.render

        expect(output).not_to include("pg_reports_row{")
      end

      it "skips nil column values" do
        PgReports::Modules::Indexes.tap do |mod|
          allow(mod).to receive(:unused_indexes).and_return(
            fake_report([{"index_name" => "idx_a", "table_name" => nil, "idx_scan" => 0}])
          )
        end

        output = described_class.render

        expect(output).to include('index_name="idx_a"')
        expect(output).not_to include("table_name=")
      end

      it "skips column values that exceed MAX_LABEL_VALUE_LENGTH" do
        long = "x" * (PgReports::Grafana::Exporter::MAX_LABEL_VALUE_LENGTH + 1)
        allow(PgReports::Modules::Indexes).to receive(:unused_indexes).and_return(
          fake_report([{"index_name" => "idx_a", "comment" => long}])
        )

        output = described_class.render

        expect(output).to include('index_name="idx_a"')
        expect(output).not_to include("comment=")
      end

      it "sanitizes column names that aren't valid Prometheus label names" do
        allow(PgReports::Modules::Indexes).to receive(:unused_indexes).and_return(
          fake_report([{"weird-name" => "ok", "1leading_digit" => "ok"}])
        )

        output = described_class.render

        # weird-name → weird_name, 1leading_digit → _1leading_digit
        expect(output).to include('weird_name="ok"')
        expect(output).to include('_1leading_digit="ok"')
        expect(output).not_to include("weird-name=")
      end

      it "drops user columns that collide with reserved label names" do
        allow(PgReports::Modules::Indexes).to receive(:unused_indexes).and_return(
          fake_report([{"report" => "should_be_dropped", "index_name" => "idx_a", "row" => 99}])
        )

        output = described_class.render

        # row label always equals the index, never the user-supplied 99
        expect(output).to match(/pg_reports_row\{[^}]*report="unused_indexes"[^}]*\}/)
        expect(output).not_to include('"should_be_dropped"')
        expect(output).not_to match(/row="99"/)
      end

      it "is omitted entirely when no favorites expose rows" do
        PgReports::Modules::Indexes.tap do |mod|
          allow(mod).to receive(:unused_indexes).and_return(fake_report([]))
        end

        output = described_class.render

        expect(output).not_to include("pg_reports_row{")
      end
    end

    context "label escaping" do
      it "escapes backslashes and quotes in labels" do
        boom = Class.new(StandardError) {
          def self.name
            'A"B\\C'
          end
        }
        PgReports.config.grafana_favorites = [:slow_queries]
        allow(PgReports::Modules::Queries).to receive(:slow_queries).and_raise(boom)

        output = described_class.render

        expect(output).to include('error="A\\"B\\\\C"')
      end
    end
  end

  describe "caching" do
    let(:rows) { [{"a" => 1}] }
    let(:cache) { ActiveSupport::Cache::MemoryStore.new }

    before do
      stub_const("Rails", double(cache: cache))
      PgReports.config.grafana_favorites = [:row_counts]
      PgReports.config.grafana_cache_ttl = 60
      allow(PgReports::Modules::Tables).to receive(:row_counts).and_return(fake_report(rows))
    end

    it "calls the underlying report only once within TTL" do
      described_class.render
      described_class.render

      expect(PgReports::Modules::Tables).to have_received(:row_counts).once
    end

    it "skips cache when ttl is nil" do
      PgReports.config.grafana_cache_ttl = nil

      described_class.render
      described_class.render

      expect(PgReports::Modules::Tables).to have_received(:row_counts).twice
    end
  end
end
