# frozen_string_literal: true

module PgReports
  module Modules
    # Table analysis module
    module Tables
      extend self

      # Table sizes including indexes
      # @return [Report] Report with table sizes
      def table_sizes(limit: 50)
        data = executor.execute_from_file(:tables, :table_sizes)
          .first(limit)

        Report.new(
          title: "Table Sizes (top #{limit})",
          data: data,
          columns: %w[schema table_name table_size_mb index_size_mb total_size_mb row_count]
        )
      end

      # Bloated tables - tables with high dead tuple ratio
      # @return [Report] Report with bloated tables
      def bloated_tables(limit: 20)
        data = executor.execute_from_file(:tables, :bloated_tables)
        threshold = PgReports.config.bloat_threshold_percent

        filtered = data.select { |row| row["bloat_percent"].to_f >= threshold }
          .first(limit)

        Report.new(
          title: "Bloated Tables (bloat >= #{threshold}%)",
          data: filtered,
          columns: %w[schema table_name live_rows dead_rows bloat_percent table_size_mb]
        )
      end

      # Tables needing vacuum - high dead rows count
      # @return [Report] Report with tables needing vacuum
      def vacuum_needed(limit: 20)
        data = executor.execute_from_file(:tables, :vacuum_needed)
        threshold = PgReports.config.dead_rows_threshold

        filtered = data.select { |row| row["n_dead_tup"].to_i >= threshold }
          .first(limit)

        Report.new(
          title: "Tables Needing Vacuum (dead rows >= #{threshold})",
          data: filtered,
          columns: %w[schema table_name n_live_tup n_dead_tup last_vacuum last_autovacuum]
        )
      end

      # Table row counts
      # @return [Report] Report with table row counts
      def row_counts(limit: 50)
        data = executor.execute_from_file(:tables, :row_counts)
          .first(limit)

        Report.new(
          title: "Table Row Counts (top #{limit})",
          data: data,
          columns: %w[schema table_name row_count table_size_mb]
        )
      end

      # Table cache hit ratios
      # @return [Report] Report with table cache hit ratios
      def cache_hit_ratios(limit: 50)
        data = executor.execute_from_file(:tables, :cache_hit_ratios)
          .first(limit)

        Report.new(
          title: "Table Cache Hit Ratios",
          data: data,
          columns: %w[schema table_name heap_blks_read heap_blks_hit cache_hit_ratio]
        )
      end

      # Sequential scan statistics
      # @return [Report] Report with sequential scan statistics
      def seq_scans(limit: 20)
        data = executor.execute_from_file(:tables, :seq_scans)
          .first(limit)

        Report.new(
          title: "Sequential Scans (top #{limit})",
          data: data,
          columns: %w[schema table_name seq_scan seq_tup_read idx_scan rows_per_seq_scan]
        )
      end

      # Recently modified tables
      # @return [Report] Report with recently modified tables
      def recently_modified(limit: 20)
        data = executor.execute_from_file(:tables, :recently_modified)
          .first(limit)

        Report.new(
          title: "Recently Modified Tables",
          data: data,
          columns: %w[schema table_name n_tup_ins n_tup_upd n_tup_del last_analyze]
        )
      end

      private

      def executor
        @executor ||= Executor.new
      end
    end
  end
end
