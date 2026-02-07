# frozen_string_literal: true

require_relative "lib/pg_reports/version"

Gem::Specification.new do |spec|
  spec.name = "pg_reports"
  spec.version = PgReports::VERSION
  spec.authors = ["Eldar Avatov"]
  spec.email = ["eldar.avatov@gmail.com"]

  spec.summary = "PostgreSQL analysis and reporting tool with Telegram integration"
  spec.description = "A comprehensive PostgreSQL monitoring and analysis library that provides " \
                     "insights into query performance, index usage, table statistics, and more. " \
                     "Includes a beautiful web dashboard and Telegram notifications."
  spec.homepage = "https://github.com/deadalice/pg_reports"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,lib}/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  end

  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "activesupport", ">= 5.0"
  spec.add_dependency "activerecord", ">= 5.0"
  spec.add_dependency "actionpack", ">= 5.0"
  spec.add_dependency "railties", ">= 5.0"
  spec.add_dependency "pg", ">= 1.0"
  spec.add_dependency "csv"

  # Optional dependencies (for Telegram support)
  # spec.add_dependency "telegram-bot-ruby", ">= 1.0"

  # Development dependencies
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "standard", "~> 1.30"
  spec.add_development_dependency "yard", "~> 0.9"
end
