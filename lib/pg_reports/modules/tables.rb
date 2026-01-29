# frozen_string_literal: true

module PgReports
  module Modules
    # Table analysis module
    # All report methods are generated from YAML definitions in lib/pg_reports/definitions/tables/
    module Tables
      extend self

      # The following methods are auto-generated from YAML:
      # - table_sizes(limit: 50)
      # - bloated_tables(limit: 20)
      # - vacuum_needed(limit: 20)
      # - row_counts(limit: 50)
      # - cache_hit_ratios(limit: 50)
      # - seq_scans(limit: 20)
      # - recently_modified(limit: 20)

      private

      def executor
        @executor ||= Executor.new
      end
    end
  end
end
