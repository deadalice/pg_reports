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
        temp_file_queries: {
          thresholds: {temp_mb_written: {warning: 100, critical: 1000}},
          problem_fields: ["temp_mb_written"]
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
        inefficient_indexes: {
          thresholds: {read_to_fetch_ratio: {warning: 10, critical: 100}},
          problem_fields: ["read_to_fetch_ratio"]
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
        fk_without_indexes: {
          thresholds: {},
          problem_fields: ["child_table_size_mb"]
        },
        index_correlation: {
          thresholds: {correlation: {warning: 0.5, critical: 0.2, inverted: true}},
          problem_fields: ["correlation"]
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
        tables_without_pk: {
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
        wraparound_risk: {
          thresholds: {pct_towards_wraparound: {warning: 50, critical: 75}},
          problem_fields: ["pct_towards_wraparound"]
        },
        checkpoint_stats: {
          thresholds: {requested_pct: {warning: 50, critical: 75}},
          problem_fields: ["requested_pct"]
        },

        # === SCHEMA ANALYSIS ===
        missing_validations: {
          thresholds: {},
          problem_fields: []
        },
        unused_columns: {
          thresholds: {},
          problem_fields: ["column_name"]
        },
        always_null_columns: {
          thresholds: {null_pct: {warning: 99, critical: 100}},
          problem_fields: ["column_name", "null_pct"]
        },
        polymorphic_without_index: {
          thresholds: {},
          problem_fields: ["coverage"]
        },
        counter_cache_issues: {
          thresholds: {},
          problem_fields: ["issue", "expected_column"]
        },
        soft_delete_without_scope: {
          thresholds: {},
          problem_fields: ["status", "soft_delete_column"]
        },
        orphan_tables: {
          thresholds: {},
          problem_fields: ["classification"]
        },

        # === TABLES (extra) ===
        update_hotspots: {
          thresholds: {
            updates_per_row: {warning: 10, critical: 100},
            hot_update_pct: {warning: 50, critical: 20, inverted: true}
          },
          problem_fields: ["updates_per_row", "hot_update_pct"]
        },
        unused_tables: {
          thresholds: {total_size_mb: {warning: 10, critical: 100}},
          problem_fields: ["table_name"]
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
            temp_file_queries: {name: "Temp File Queries", description: "Queries spilling to disk"},
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
            inefficient_indexes: {name: "Inefficient Indexes", description: "Indexes with high read-to-fetch ratio"},
            index_usage: {name: "Index Usage", description: "Index scan statistics"},
            bloated_indexes: {name: "Bloated Indexes", description: "Indexes with high bloat"},
            fk_without_indexes: {name: "FK Without Indexes", description: "Foreign keys missing indexes"},
            index_correlation: {name: "Index Correlation", description: "Low physical correlation indexes"},
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
            tables_without_pk: {name: "No Primary Key", description: "Tables missing primary keys"},
            recently_modified: {name: "Recently Modified", description: "Tables with recent activity"},
            update_hotspots: {name: "Update Hotspots", description: "Same rows or indexed columns updated repeatedly"},
            unused_tables: {name: "Unused Tables", description: "Tables never queried since the last stats reset"}
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
            wraparound_risk: {name: "Wraparound Risk", description: "Transaction ID wraparound proximity"},
            checkpoint_stats: {name: "Checkpoint Stats", description: "Checkpoint and bgwriter statistics"},
            cache_stats: {name: "Cache Stats", description: "Database cache statistics"}
          }
        },
        schema_analysis: {
          name: "Schema Analysis",
          icon: "🔍",
          color: "#06b6d4",
          # These reports introspect the host application's ActiveRecord models,
          # which are bound to the default database. Running them against a
          # different database in the cluster returns rows that may not map to
          # any model. The dashboard greys the category out in that case.
          target_constraint: :primary_default_database_only,
          reports: {
            missing_validations: {name: "Missing Validations", description: "Unique indexes without model validations"},
            unused_columns: {name: "Unused Columns", description: "Columns that have only ever held a single value"},
            always_null_columns: {name: "Always-NULL Columns", description: "Nullable columns that contain only NULL"},
            polymorphic_without_index: {name: "Polymorphic Without Index", description: "Polymorphic associations missing composite index"},
            counter_cache_issues: {name: "Counter Cache Issues", description: "counter_cache declarations whose target column is missing"},
            soft_delete_without_scope: {name: "Soft Delete Without Scope", description: "Soft-delete columns with no model scope filtering them"},
            orphan_tables: {name: "Orphan Tables", description: "DB tables without a corresponding Rails model"}
          }
        }
      }.freeze

      def self.all
        REPORTS.each_with_object({}) do |(cat_key, cat), result|
          result[cat_key] = localized_category(cat_key, cat)
        end
      end

      def self.find(category, report)
        rep = REPORTS.dig(category.to_sym, :reports, report.to_sym)
        return nil unless rep

        localized_report(report.to_sym, rep)
      end

      def self.category(category)
        cat = REPORTS[category.to_sym]
        return nil unless cat

        localized_category(category.to_sym, cat)
      end

      # Build category hash with localized name and report names
      def self.localized_category(cat_key, cat)
        cat.merge(
          name: I18n.t("pg_reports.categories.#{cat_key}", default: cat[:name]),
          reports: cat[:reports].each_with_object({}) do |(rep_key, rep), reports|
            reports[rep_key] = localized_report(rep_key, rep)
          end
        )
      end

      # Build report hash with localized name and description
      def self.localized_report(rep_key, rep)
        rep.merge(
          name: I18n.t("pg_reports.reports.#{rep_key}.name", default: rep[:name]),
          description: I18n.t("pg_reports.reports.#{rep_key}.description", default: rep[:description])
        )
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
          ai_prompt: I18n.t("#{i18n_key}.ai_prompt", default: nil),
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

      # Returns the target constraint declared on a category, or nil.
      # Currently the only constraint is :primary_default_database_only, which
      # means "only meaningful when the dashboard is pointing at the host app's
      # primary target on its default database" — used by Schema Analysis,
      # which depends on ActiveRecord::Base.descendants of the host app.
      def self.target_constraint(category)
        REPORTS.dig(category.to_sym, :target_constraint)
      end
    end
  end
end
