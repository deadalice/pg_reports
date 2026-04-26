# frozen_string_literal: true

require "json"

namespace :pg_reports do
  namespace :grafana do
    desc "Write importable Grafana dashboard JSON for the configured grafana_favorites. " \
         "Defaults to pg_reports.json in pwd. Override with OUTPUT=, FAVORITES=, TITLE=, UID=, REFRESH=, TIME_FROM=."
    task dashboard: :environment do
      favorites = if ENV["FAVORITES"]
        ENV["FAVORITES"].split(",").map { |k| k.strip.to_sym }
      else
        PgReports.config.grafana_favorites
      end

      builder = PgReports::Grafana::DashboardBuilder.new(
        favorites: favorites,
        title: ENV.fetch("TITLE", PgReports::Grafana::DashboardBuilder::DEFAULT_TITLE),
        uid: ENV.fetch("UID", PgReports::Grafana::DashboardBuilder::DEFAULT_UID),
        refresh: ENV.fetch("REFRESH", "1m"),
        time_from: ENV.fetch("TIME_FROM", "now-6h")
      )

      output_path = ENV.fetch("OUTPUT", "pg_reports.json")
      File.write(output_path, JSON.pretty_generate(builder.build))
      warn "Wrote #{output_path}"
    end

    desc "Write the current /metrics payload to a file. Defaults to pg_reports.metrics in pwd. Override with OUTPUT=."
    task metrics: :environment do
      output_path = ENV.fetch("OUTPUT", "pg_reports.metrics")
      File.write(output_path, PgReports::Grafana::Exporter.render)
      warn "Wrote #{output_path}"
    end
  end
end
