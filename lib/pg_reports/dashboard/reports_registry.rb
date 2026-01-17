# frozen_string_literal: true

module PgReports
  module Dashboard
    # Registry of all available reports for the dashboard
    module ReportsRegistry
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
            idle_connections: {name: "Idle Connections", description: "Idle connections"}
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
    end
  end
end
