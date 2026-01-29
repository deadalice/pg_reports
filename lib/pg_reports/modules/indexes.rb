# frozen_string_literal: true

module PgReports
  module Modules
    # Index analysis module
    # All report methods are generated from YAML definitions in lib/pg_reports/definitions/indexes/
    module Indexes
      extend self

      # The following methods are auto-generated from YAML:
      # - unused_indexes(limit: 50)
      # - duplicate_indexes
      # - invalid_indexes
      # - missing_indexes(limit: 20)
      # - index_usage(limit: 50)
      # - bloated_indexes(limit: 20)
      # - index_sizes(limit: 50)

      private

      def executor
        @executor ||= Executor.new
      end
    end
  end
end
