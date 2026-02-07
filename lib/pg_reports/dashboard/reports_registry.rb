# frozen_string_literal: true

module PgReports
  module Dashboard
    # Registry of all available reports for the dashboard
    module ReportsRegistry
      # Thresholds and problem field configuration for each report
      # Text documentation is stored in I18n locale files (config/locales/*.yml)
      REPORT_CONFIG = {
        # === QUERIES ===
        slow_queries: {
          thresholds: {mean_time_ms: {warning: 100, critical: 500}},
          problem_fields: ["mean_time_ms"]
        },
        heavy_queries: {
          thresholds: {calls: {warning: 10000, critical: 100000}},
          problem_fields: ["calls"]
        },
        expensive_queries: {
          thresholds: {total_time_ms: {warning: 60000, critical: 300000}},
          problem_fields: ["total_time_ms"]
        },
        missing_index_queries: {
          thresholds: {seq_tup_read: {warning: 100000, critical: 1000000}},
          problem_fields: ["seq_tup_read", "seq_scan"]
        },
        low_cache_hit_queries: {
          thresholds: {cache_hit_ratio: {warning: 0.95, critical: 0.80, inverted: true}},
          problem_fields: ["cache_hit_ratio"]
        },
        all_queries: {
          thresholds: {},
          problem_fields: []
        },

        # === INDEXES ===
        unused_indexes: {
          thresholds: {idx_scan: {warning: 10, critical: 0, inverted: true}},
          problem_fields: ["idx_scan"]
        },
        duplicate_indexes: {
          thresholds: {},
          problem_fields: []
        },
        invalid_indexes: {
          thresholds: {},
          problem_fields: []
        },
        missing_indexes: {
          thresholds: {seq_scan_ratio: {warning: 0.5, critical: 0.9}},
          problem_fields: ["seq_scan", "seq_tup_read"]
        },
        index_usage: {
          thresholds: {},
          problem_fields: []
        },
        bloated_indexes: {
          thresholds: {bloat_ratio: {warning: 0.3, critical: 0.5}},
          problem_fields: ["bloat_ratio", "bloat_size"]
        },
        index_sizes: {
          thresholds: {size_bytes: {warning: 1073741824, critical: 10737418240}},
          problem_fields: ["size_bytes"]
        },

        # === TABLES ===
        table_sizes: {
          thresholds: {total_size_bytes: {warning: 10737418240, critical: 107374182400}},
          problem_fields: ["total_size_bytes"]
        },
        bloated_tables: {
          thresholds: {dead_tuple_ratio: {warning: 0.1, critical: 0.2}},
          problem_fields: ["dead_tuple_ratio", "n_dead_tup"]
        },
        vacuum_needed: {
          thresholds: {n_dead_tup: {warning: 10000, critical: 100000}},
          problem_fields: ["n_dead_tup"]
        },
        row_counts: {
          thresholds: {},
          problem_fields: []
        },
        cache_hit_ratios: {
          thresholds: {cache_hit_ratio: {warning: 0.95, critical: 0.80, inverted: true}},
          problem_fields: ["cache_hit_ratio"]
        },
        seq_scans: {
          thresholds: {seq_scan: {warning: 1000, critical: 10000}},
          problem_fields: ["seq_scan", "seq_tup_read"]
        },
        recently_modified: {
          thresholds: {},
          problem_fields: []
        },

        # === CONNECTIONS ===
        active_connections: {
          thresholds: {connection_count: {warning: 50, critical: 100}},
          problem_fields: ["connection_count"]
        },
        connection_stats: {
          thresholds: {idle_in_transaction: {warning: 5, critical: 20}},
          problem_fields: ["idle_in_transaction"]
        },
        long_running_queries: {
          thresholds: {duration_seconds: {warning: 60, critical: 300}},
          problem_fields: ["duration_seconds", "duration"]
        },
        blocking_queries: {
          thresholds: {blocked_count: {warning: 1, critical: 5}},
          problem_fields: ["blocked_count"]
        },
        locks: {
          thresholds: {waiting_locks: {warning: 5, critical: 20}},
          problem_fields: ["waiting_locks"]
        },
        idle_connections: {
          thresholds: {idle_count: {warning: 30, critical: 80}},
          problem_fields: ["idle_count"]
        },
        pool_usage: {
          thresholds: {utilization_pct: {warning: 70, critical: 85}},
          problem_fields: ["utilization_pct"]
        },
        pool_wait_times: {
          thresholds: {wait_duration_seconds: {warning: 10, critical: 60}},
          problem_fields: ["wait_duration_seconds"]
        },
        pool_saturation: {
          thresholds: {utilization_pct: {warning: 70, critical: 85}},
          problem_fields: ["utilization_pct"]
        },
        connection_churn: {
          thresholds: {
            churn_rate_pct: {warning: 50, critical: 75},
            short_lived_connections: {warning: 10, critical: 25}
          },
          problem_fields: ["churn_rate_pct", "short_lived_connections"]
        },

        # === SYSTEM ===
        database_sizes: {
          thresholds: {size_bytes: {warning: 10737418240, critical: 107374182400}},
          problem_fields: ["size_bytes"]
        },
        settings: {
          thresholds: {},
          problem_fields: []
        },
        extensions: {
          thresholds: {},
          problem_fields: []
        },
        activity_overview: {
          thresholds: {},
          problem_fields: []
        },
        cache_stats: {
          thresholds: {cache_hit_ratio: {warning: 0.95, critical: 0.90, inverted: true}},
          problem_fields: ["cache_hit_ratio"]
        },

        # === SCHEMA ANALYSIS ===
        missing_validations: {
          thresholds: {},
          problem_fields: []
        }
      }.freeze

      REPORTS = {
        queries: {
          name: "Queries",
          icon: "⚡",
          color: "#6366f1",
          reports: {
            slow_queries: {name: "Slow Queries", description: "Queries with high mean execution time"},
            heavy_queries: {name: "Heavy Queries", description: "Most frequently called queries"},
            expensive_queries: {name: "Expensive Queries", description: "Queries consuming most total time"},
            missing_index_queries: {name: "Missing Index Queries", description: "Queries potentially missing indexes"},
            low_cache_hit_queries: {name: "Low Cache Hit", description: "Queries with poor cache utilization"},
            all_queries: {name: "All Queries", description: "All query statistics"}
          }
        },
        indexes: {
          name: "Indexes",
          icon: "📇",
          color: "#10b981",
          reports: {
            unused_indexes: {name: "Unused Indexes", description: "Indexes rarely or never scanned"},
            duplicate_indexes: {name: "Duplicate Indexes", description: "Redundant indexes"},
            invalid_indexes: {name: "Invalid Indexes", description: "Indexes that failed to build"},
            missing_indexes: {name: "Missing Indexes", description: "Tables potentially missing indexes"},
            index_usage: {name: "Index Usage", description: "Index scan statistics"},
            bloated_indexes: {name: "Bloated Indexes", description: "Indexes with high bloat"},
            index_sizes: {name: "Index Sizes", description: "Index disk usage"}
          }
        },
        tables: {
          name: "Tables",
          icon: "📊",
          color: "#f59e0b",
          reports: {
            table_sizes: {name: "Table Sizes", description: "Table disk usage"},
            bloated_tables: {name: "Bloated Tables", description: "Tables with high dead tuple ratio"},
            vacuum_needed: {name: "Vacuum Needed", description: "Tables needing vacuum"},
            row_counts: {name: "Row Counts", description: "Table row counts"},
            cache_hit_ratios: {name: "Cache Hit Ratios", description: "Table cache statistics"},
            seq_scans: {name: "Sequential Scans", description: "Tables with high sequential scans"},
            recently_modified: {name: "Recently Modified", description: "Tables with recent activity"}
          }
        },
        connections: {
          name: "Connections",
          icon: "🔌",
          color: "#ec4899",
          reports: {
            active_connections: {name: "Active Connections", description: "Current database connections"},
            connection_stats: {name: "Connection Stats", description: "Connection statistics by state"},
            long_running_queries: {name: "Long Running", description: "Queries running for extended period"},
            blocking_queries: {name: "Blocking Queries", description: "Queries blocking others"},
            locks: {name: "Locks", description: "Current database locks"},
            idle_connections: {name: "Idle Connections", description: "Idle connections"},
            pool_usage: {name: "Pool Usage", description: "Connection pool utilization"},
            pool_wait_times: {name: "Wait Times", description: "Resource wait analysis"},
            pool_saturation: {name: "Pool Saturation", description: "Pool health warnings"},
            connection_churn: {name: "Connection Churn", description: "Connection lifecycle analysis"}
          }
        },
        system: {
          name: "System",
          icon: "🖥️",
          color: "#8b5cf6",
          reports: {
            database_sizes: {name: "Database Sizes", description: "Size of all databases"},
            settings: {name: "Settings", description: "PostgreSQL configuration"},
            extensions: {name: "Extensions", description: "Installed extensions"},
            activity_overview: {name: "Activity Overview", description: "Current activity summary"},
            cache_stats: {name: "Cache Stats", description: "Database cache statistics"}
          }
        },
        schema_analysis: {
          name: "Schema Analysis",
          icon: "🔍",
          color: "#06b6d4",
          reports: {
            missing_validations: {name: "Missing Validations", description: "Unique indexes without model validations"}
          }
        }
      }.freeze

      def self.all
        REPORTS
      end

      def self.find(category, report)
        REPORTS.dig(category.to_sym, :reports, report.to_sym)
      end

      def self.category(category)
        REPORTS[category.to_sym]
      end

      # Returns full documentation for a report including I18n translations
      def self.documentation(report)
        report_key = report.to_sym
        config = REPORT_CONFIG[report_key] || {thresholds: {}, problem_fields: []}

        # Get translations from I18n
        i18n_key = "pg_reports.documentation.#{report_key}"
        {
          title: I18n.t("#{i18n_key}.title", default: report.to_s.titleize),
          what: I18n.t("#{i18n_key}.what", default: ""),
          how: I18n.t("#{i18n_key}.how", default: ""),
          nuances: I18n.t("#{i18n_key}.nuances", default: []),
          thresholds: config[:thresholds],
          problem_fields: config[:problem_fields]
        }
      end

      # Returns the problem explanation for a given problem type
      def self.problem_explanation(problem_key)
        I18n.t("pg_reports.problems.#{problem_key}", default: "")
      end

      # Returns thresholds for a report
      def self.thresholds(report)
        REPORT_CONFIG.dig(report.to_sym, :thresholds) || {}
      end

      # Returns problem fields for a report
      def self.problem_fields(report)
        REPORT_CONFIG.dig(report.to_sym, :problem_fields) || []
      end
    end
  end
end
