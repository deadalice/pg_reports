# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "debug"
  gem "standard"
  # Web server for the standalone dashboard (`bin/pg_reports server`).
  # Not a gem runtime dependency — the standalone runner picks any available
  # Rack server at run time; this just guarantees one in the repo's bundle.
  gem "puma"
end

group :test do
  gem "database_cleaner-active_record"
  gem "factory_bot_rails"
end
