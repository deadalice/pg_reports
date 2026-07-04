# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"
RuboCop::RakeTask.new

task default: %i[spec rubocop]

namespace :pg_reports do
  desc "Run the standalone dashboard (PORT, HOST, DATABASE_URL, CONFIG env vars honored)"
  task :server do
    $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
    require "pg_reports"
    PgReports::Standalone.run(
      port: (ENV["PORT"] || PgReports::Standalone::DEFAULT_PORT).to_i,
      host: ENV["HOST"] || PgReports::Standalone::DEFAULT_HOST,
      config_file: ENV["CONFIG"]
    )
  end
end
