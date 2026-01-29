# frozen_string_literal: true

module PgReports
  module Modules
    # Query analysis module - analyzes pg_stat_statements data
    # Most report methods are generated from YAML definitions in lib/pg_reports/definitions/queries/
    module Queries
      extend self

      # The following methods are auto-generated from YAML:
      # - slow_queries(limit: 20)
      # - heavy_queries(limit: 20)
      # - expensive_queries(limit: 20)
      # - missing_index_queries(limit: 20)
      # - low_cache_hit_queries(limit: 20, min_calls: 100)
      # - all_queries(limit: 50)

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
      # Used by YAML-based reports via enrichment hook
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
