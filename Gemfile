# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "debug"
  # `standard` (the linter) is declared in the gemspec's development
  # dependencies so there is a single, version-constrained source of truth.
  # Web server for the standalone dashboard (`bin/pg_reports server`).
  # Not a gem runtime dependency — the standalone runner picks any available
  # Rack server at run time; this just guarantees one in the repo's bundle.
  gem "puma"
  # Security scanning (see the `security` CI job).
  gem "brakeman", require: false
  gem "bundler-audit", require: false
end

group :test do
  gem "database_cleaner-active_record"
  gem "factory_bot_rails"
  # Code coverage; started at the top of spec/spec_helper.rb.
  gem "simplecov", require: false
end
