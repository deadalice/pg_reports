# frozen_string_literal: true

require "json"

module PgReports
  module Grafana
    # Builds an importable Grafana dashboard JSON from configured favorites.
    # Each report becomes a row with two panels:
    #   - "rows" stat (total)
    #   - "issues by severity" timeseries (ok / warning / critical)
    # Severity colours are wired so that any warning lights yellow, any critical lights red.
    class DashboardBuilder
      DATASOURCE_INPUT = "DS_PROMETHEUS"

      DEFAULT_TITLE = "PgReports — PostgreSQL Health"
      DEFAULT_UID = "pg-reports"

      SEVERITY_COLORS = {
        "ok" => "green",
        "warning" => "yellow",
        "critical" => "red"
      }.freeze

      GRID_WIDTH = 24
      ROW_HEIGHT = 1
      TIMESERIES_HEIGHT = 8
      TABLE_HEIGHT = 10
      REPORT_BLOCK_HEIGHT = TIMESERIES_HEIGHT + TABLE_HEIGHT

      def self.build(**opts)
        new(**opts).build
      end

      def initialize(favorites: PgReports.config.grafana_favorites,
        title: DEFAULT_TITLE,
        uid: DEFAULT_UID,
        refresh: "1m",
        time_from: "now-6h")
        @favorites = normalize(favorites)
        @title = title
        @uid = uid
        @refresh = refresh
        @time_from = time_from
        @panel_id = 0
      end

      def build
        if @favorites.empty?
          raise ArgumentError,
            "No favorites configured. Set PgReports.config.grafana_favorites or pass favorites:."
        end

        {
          "__inputs" => [datasource_input],
          "__requires" => [grafana_require, prometheus_require],
          "annotations" => {"list" => []},
          "editable" => true,
          "graphTooltip" => 1,
          "panels" => build_panels,
          "refresh" => @refresh,
          "schemaVersion" => 38,
          "tags" => ["pg_reports", "postgresql"],
          "templating" => {"list" => []},
          "time" => {"from" => @time_from, "to" => "now"},
          "timezone" => "browser",
          "title" => @title,
          "uid" => @uid,
          "version" => 1,
          "weekStart" => ""
        }
      end

      def to_json(*)
        JSON.pretty_generate(build)
      end

      private

      def normalize(favorites)
        case favorites
        when Hash then favorites.keys.map(&:to_sym)
        when Array then favorites.map(&:to_sym)
        else []
        end
      end

      def build_panels
        panels = []
        y = 0

        grouped_favorites.each do |category, keys|
          panels << row_panel(category_label(category), y)
          y += ROW_HEIGHT

          keys.each do |key|
            info = report_info(category, key)
            panels << timeseries_panel(key, info, y)
            panels << table_panel(key, info, y + TIMESERIES_HEIGHT)
            y += REPORT_BLOCK_HEIGHT
          end
        end

        panels
      end

      def grouped_favorites
        groups = {}
        @favorites.each do |key|
          category = category_for(key)
          next unless category # silently skip unknown keys; exporter logs them
          groups[category] ||= []
          groups[category] << key
        end
        groups
      end

      def category_for(key)
        Dashboard::ReportsRegistry::REPORTS.each do |category, info|
          return category if info[:reports].key?(key)
        end
        nil
      end

      def category_label(category)
        Dashboard::ReportsRegistry::REPORTS.dig(category, :name) || category.to_s.humanize
      end

      def report_info(category, key)
        Dashboard::ReportsRegistry::REPORTS.dig(category, :reports, key) || {name: key.to_s.humanize, description: ""}
      end

      def row_panel(title, y)
        {
          "id" => next_id,
          "type" => "row",
          "title" => title,
          "collapsed" => false,
          "gridPos" => {"h" => ROW_HEIGHT, "w" => GRID_WIDTH, "x" => 0, "y" => y},
          "panels" => []
        }
      end

      def timeseries_panel(key, info, y)
        {
          "id" => next_id,
          "type" => "timeseries",
          "title" => "#{info[:name]} — issues by severity",
          "description" => info[:description].to_s,
          "datasource" => datasource_ref,
          "gridPos" => {"h" => TIMESERIES_HEIGHT, "w" => GRID_WIDTH, "x" => 0, "y" => y},
          "targets" => severity_targets(key),
          "options" => {
            "legend" => {"displayMode" => "table", "placement" => "right", "calcs" => ["lastNotNull"]},
            "tooltip" => {"mode" => "multi", "sort" => "desc"}
          },
          "fieldConfig" => {
            "defaults" => {
              "custom" => {
                "drawStyle" => "bars",
                "stacking" => {"mode" => "normal", "group" => "A"},
                "fillOpacity" => 60,
                "lineWidth" => 1
              },
              "color" => {"mode" => "fixed"},
              "mappings" => []
            },
            "overrides" => severity_color_overrides
          }
        }
      end

      def table_panel(key, info, y)
        {
          "id" => next_id,
          "type" => "table",
          "title" => "#{info[:name]} — current rows",
          "description" => "#{info[:description]}\n\nLatest snapshot of report rows. Each row's columns are unpacked from Prometheus labels via the Labels-to-fields transformation.".strip,
          "datasource" => datasource_ref,
          "gridPos" => {"h" => TABLE_HEIGHT, "w" => GRID_WIDTH, "x" => 0, "y" => y},
          "targets" => [
            {
              "refId" => "A",
              "expr" => %(pg_reports_row{report="#{key}"}),
              "datasource" => datasource_ref,
              "format" => "table",
              "instant" => true,
              "legendFormat" => "__auto"
            }
          ],
          "transformations" => [
            {
              "id" => "labelsToFields",
              "options" => {"mode" => "columns"}
            },
            {
              "id" => "organize",
              "options" => {
                "excludeByName" => {
                  "Time" => true,
                  "Value" => true,
                  "__name__" => true,
                  "instance" => true,
                  "job" => true,
                  "report" => true,
                  "row" => true
                },
                "indexByName" => {},
                "renameByName" => {}
              }
            }
          ],
          "options" => {
            "showHeader" => true,
            "cellHeight" => "sm",
            "footer" => {"show" => false}
          },
          "fieldConfig" => {
            "defaults" => {
              "custom" => {"align" => "auto", "displayMode" => "auto"},
              "mappings" => []
            },
            "overrides" => []
          }
        }
      end

      def severity_targets(key)
        SEVERITY_COLORS.keys.each_with_index.map do |severity, i|
          {
            "refId" => ("A".ord + i).chr,
            "expr" => %(pg_reports_issues{report="#{key}",severity="#{severity}"}),
            "datasource" => datasource_ref,
            "legendFormat" => severity
          }
        end
      end

      def severity_color_overrides
        SEVERITY_COLORS.map do |severity, color|
          {
            "matcher" => {"id" => "byName", "options" => severity},
            "properties" => [
              {"id" => "color", "value" => {"mode" => "fixed", "fixedColor" => color}}
            ]
          }
        end
      end

      def datasource_input
        {
          "name" => DATASOURCE_INPUT,
          "label" => "Prometheus",
          "description" => "Datasource that scrapes /pg_reports/metrics",
          "type" => "datasource",
          "pluginId" => "prometheus",
          "pluginName" => "Prometheus"
        }
      end

      def datasource_ref
        {"type" => "prometheus", "uid" => "${#{DATASOURCE_INPUT}}"}
      end

      def grafana_require
        {"type" => "grafana", "id" => "grafana", "name" => "Grafana", "version" => "9.0.0"}
      end

      def prometheus_require
        {"type" => "datasource", "id" => "prometheus", "name" => "Prometheus", "version" => "1.0.0"}
      end

      def next_id
        @panel_id += 1
      end
    end
  end
end
