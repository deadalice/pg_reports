# frozen_string_literal: true

module PgReports
  module Modules
    # Index analysis module
    module Indexes
      extend self

      # Unused indexes - indexes that are rarely or never scanned
      # @return [Report] Report with unused indexes
      def unused_indexes(limit: 50)
        data = executor.execute_from_file(:indexes, :unused_indexes)
        threshold = PgReports.config.unused_index_threshold_scans

        filtered = data.select { |row| row["idx_scan"].to_i <= threshold }
          .first(limit)

        Report.new(
          title: "Unused Indexes (scans <= #{threshold})",
          data: filtered,
          columns: %w[schema table_name index_name idx_scan index_size_mb]
        )
      end

      # Duplicate indexes - indexes that may be redundant
      # @return [Report] Report with duplicate indexes
      def duplicate_indexes
        data = executor.execute_from_file(:indexes, :duplicate_indexes)

        Report.new(
          title: "Duplicate Indexes",
          data: data,
          columns: %w[table_name index_name duplicate_of index_size_mb]
        )
      end

      # Invalid indexes - indexes that are not valid (e.g., failed to build)
      # @return [Report] Report with invalid indexes
      def invalid_indexes
        data = executor.execute_from_file(:indexes, :invalid_indexes)

        Report.new(
          title: "Invalid Indexes",
          data: data,
          columns: %w[schema table_name index_name index_definition]
        )
      end

      # Missing indexes - tables with high sequential scans
      # @return [Report] Report suggesting missing indexes
      def missing_indexes(limit: 20)
        data = executor.execute_from_file(:indexes, :missing_indexes)
          .first(limit)

        Report.new(
          title: "Tables Potentially Missing Indexes",
          data: data,
          columns: %w[schema table_name seq_scan seq_tup_read idx_scan table_size_mb]
        )
      end

      # Index usage statistics
      # @return [Report] Report with index usage statistics
      def index_usage(limit: 50)
        data = executor.execute_from_file(:indexes, :index_usage)
          .first(limit)

        Report.new(
          title: "Index Usage Statistics",
          data: data,
          columns: %w[schema table_name index_name idx_scan idx_tup_read index_size_mb]
        )
      end

      # Bloated indexes - indexes with high bloat
      # @return [Report] Report with bloated indexes
      def bloated_indexes(limit: 20)
        data = executor.execute_from_file(:indexes, :bloated_indexes)
        threshold = PgReports.config.bloat_threshold_percent

        filtered = data.select { |row| row["bloat_percent"].to_f >= threshold }
          .first(limit)

        Report.new(
          title: "Bloated Indexes (bloat >= #{threshold}%)",
          data: filtered,
          columns: %w[schema table_name index_name index_size_mb bloat_size_mb bloat_percent]
        )
      end

      # Index sizes
      # @return [Report] Report with index sizes
      def index_sizes(limit: 50)
        data = executor.execute_from_file(:indexes, :index_sizes)
          .first(limit)

        Report.new(
          title: "Index Sizes (top #{limit})",
          data: data,
          columns: %w[schema table_name index_name index_size_mb]
        )
      end

      private

      def executor
        @executor ||= Executor.new
      end
    end
  end
end
