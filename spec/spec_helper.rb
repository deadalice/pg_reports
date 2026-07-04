# frozen_string_literal: true

require "bundler/setup"

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/"
  add_group "Modules", "lib/pg_reports/modules"
  add_group "Connection", "lib/pg_reports/connection"
  add_group "Dashboard", %w[lib/pg_reports/dashboard app/controllers]
  add_group "Grafana", "lib/pg_reports/grafana"

  # Conservative floor to catch large regressions, not to chase 100%.
  # Bump this up as coverage improves. Skip enforcement across the Rails
  # matrix (some code paths are version-gated); enforce on the main job only.
  minimum_coverage(line: 55) unless ENV["COVERAGE_NO_MIN"] == "1"
end

require "pg_reports"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!

  config.order = :random
  Kernel.srand config.seed
end
