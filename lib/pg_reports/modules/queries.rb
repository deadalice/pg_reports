# frozen_string_literal: true

module PgReports
  module Modules
    # Query analysis module - analyzes pg_stat_statements data
    module Queries
      extend self

      # Slow queries - queries with high mean execution time
      # @return [Report] Report with slow queries
      def slow_queries(limit: 20)
        data = executor.execute_from_file(:queries, :slow_queries)
        threshold = PgReports.config.slow_query_threshold_ms

        filtered = data.select { |row| row["mean_time_ms"].to_f >= threshold }
          .first(limit)

        enriched = enrich_with_annotations(filtered)

        Report.new(
          title: "Slow Queries (mean time >= #{threshold}ms)",
          data: enriched,
          columns: %w[query source calls mean_time_ms total_time_ms rows_per_call]
        )
      end

      # Heavy queries - queries called most frequently
      # @return [Report] Report with heavy queries
      def heavy_queries(limit: 20)
        data = executor.execute_from_file(:queries, :heavy_queries)
        threshold = PgReports.config.heavy_query_threshold_calls

        filtered = data.select { |row| row["calls"].to_i >= threshold }
          .first(limit)

        enriched = enrich_with_annotations(filtered)

        Report.new(
          title: "Heavy Queries (calls >= #{threshold})",
          data: enriched,
          columns: %w[query source calls total_time_ms mean_time_ms cache_hit_ratio]
        )
      end

      # Expensive queries - queries consuming most total time
      # @return [Report] Report with expensive queries
      def expensive_queries(limit: 20)
        data = executor.execute_from_file(:queries, :expensive_queries)
        threshold = PgReports.config.expensive_query_threshold_ms

        filtered = data.select { |row| row["total_time_ms"].to_f >= threshold }
          .first(limit)

        enriched = enrich_with_annotations(filtered)

        Report.new(
          title: "Expensive Queries (total time >= #{threshold}ms)",
          data: enriched,
          columns: %w[query source calls total_time_ms percent_of_total mean_time_ms]
        )
      end

      # Queries missing indexes - sequential scans on large tables
      # @return [Report] Report with queries likely missing indexes
      def missing_index_queries(limit: 20)
        data = executor.execute_from_file(:queries, :missing_index_queries)
          .first(limit)

        enriched = enrich_with_annotations(data)

        Report.new(
          title: "Queries Potentially Missing Indexes",
          data: enriched,
          columns: %w[query source calls seq_scan_count rows_examined table_name]
        )
      end

      # Queries with low cache hit ratio
      # @return [Report] Report with queries having poor cache utilization
      def low_cache_hit_queries(limit: 20, min_calls: 100)
        data = executor.execute_from_file(:queries, :low_cache_hit_queries)

        filtered = data.select { |row| row["calls"].to_i >= min_calls }
          .first(limit)

        enriched = enrich_with_annotations(filtered)

        Report.new(
          title: "Queries with Low Cache Hit Ratio (min #{min_calls} calls)",
          data: enriched,
          columns: %w[query source calls cache_hit_ratio shared_blks_hit shared_blks_read]
        )
      end

      # All query statistics ordered by total time
      # @return [Report] Report with all query statistics
      def all_queries(limit: 50)
        data = executor.execute_from_file(:queries, :all_queries)
          .first(limit)

        enriched = enrich_with_annotations(data)

        Report.new(
          title: "All Query Statistics (top #{limit})",
          data: enriched,
          columns: %w[query source calls total_time_ms mean_time_ms rows]
        )
      end

      # Reset pg_stat_statements statistics
      def reset_statistics!
        executor.execute("SELECT pg_stat_statements_reset()")
        true
      end

      private

      def executor
        @executor ||= Executor.new
      end

      # Enrich query data with parsed annotations (Marginalia, Rails QueryLogs, etc.)
      def enrich_with_annotations(data)
        data.map do |row|
          query = row["query"].to_s
          annotation = AnnotationParser.parse(query)

          if annotation.any?
            row.merge(
              "source" => AnnotationParser.format_for_display(annotation),
              "query" => AnnotationParser.strip_annotations(query)
            )
          else
            row.merge("source" => nil)
          end
        end
      end
    end
  end
end
