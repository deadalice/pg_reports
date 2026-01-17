# PgReports

[![Ruby](https://img.shields.io/badge/Ruby-2.7%2B-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-5.0%2B-red.svg)](https://rubyonrails.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive PostgreSQL monitoring and analysis library for Rails applications. Get insights into query performance, index usage, table statistics, connection health, and more. Includes a beautiful web dashboard and Telegram integration for notifications.

![Dashboard Screenshot](docs/dashboard.png)

## Features

- 📊 **Query Analysis** - Identify slow, heavy, and expensive queries using `pg_stat_statements`
- 📇 **Index Analysis** - Find unused, duplicate, invalid, and missing indexes
- 📋 **Table Statistics** - Monitor table sizes, bloat, vacuum needs, and cache hit ratios
- 🔌 **Connection Monitoring** - Track active connections, locks, and blocking queries
- 🖥️ **System Overview** - Database sizes, PostgreSQL settings, installed extensions
- 🌐 **Web Dashboard** - Beautiful dark-themed UI with expandable rows
- 📨 **Telegram Integration** - Send reports directly to Telegram
- 📥 **Export** - Download reports in TXT, CSV, or JSON format

## Installation

Add to your Gemfile:

```ruby
gem "pg_reports"

# Optional: for Telegram support
gem "telegram-bot-ruby"
```

Run:

```bash
bundle install
```

## Quick Start

### Mount the Dashboard

Add to your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # Mount in development only (recommended)
  if Rails.env.development?
    mount PgReports::Engine, at: "/pg_reports"
  end

  # Or with authentication
  authenticate :user, ->(u) { u.admin? } do
    mount PgReports::Engine, at: "/pg_reports"
  end
end
```

Visit `http://localhost:3000/pg_reports` to access the dashboard.

### Use in Console or Code

```ruby
# Get slow queries
PgReports.slow_queries.display

# Get unused indexes
report = PgReports.unused_indexes
report.each { |row| puts row["index_name"] }

# Export to different formats
report.to_text   # Plain text
report.to_csv    # CSV
report.to_a      # Array of hashes

# Send to Telegram
PgReports.expensive_queries.send_to_telegram

# Health report
PgReports.health_report.display
```

## Configuration

Create an initializer `config/initializers/pg_reports.rb`:

```ruby
PgReports.configure do |config|
  # Telegram (optional)
  config.telegram_bot_token = ENV["PG_REPORTS_TELEGRAM_TOKEN"]
  config.telegram_chat_id = ENV["PG_REPORTS_TELEGRAM_CHAT_ID"]

  # Query thresholds
  config.slow_query_threshold_ms = 100        # Queries slower than this
  config.heavy_query_threshold_calls = 1000   # Queries with more calls
  config.expensive_query_threshold_ms = 10000 # Total time threshold

  # Index thresholds
  config.unused_index_threshold_scans = 50    # Index with fewer scans

  # Table thresholds
  config.bloat_threshold_percent = 20         # Tables with more bloat
  config.dead_rows_threshold = 10000          # Dead rows needing vacuum

  # Output settings
  config.max_query_length = 200               # Truncate queries in text output

  # Dashboard authentication (optional)
  config.dashboard_auth = -> { 
    authenticate_or_request_with_http_basic do |user, pass|
      user == "admin" && pass == "secret"
    end
  }

  # Query annotation settings
  config.annotate_queries = false             # Attach annotator to ActiveRecord (opt-in)
  config.parse_annotations = true             # Parse annotations in reports
end
```

## Query Source Tracking

PgReports can show you **where queries originated** in your code. It works with:
- **Marginalia** gem annotations
- **Rails 7+ Query Logs**
- **PgReports built-in annotator**

### Using Marginalia (recommended)

If you use [marginalia](https://github.com/basecamp/marginalia), PgReports will automatically parse and display controller/action info.

### Using Rails 7+ Query Logs

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags = [:controller, :action]
```

### Using PgReports Annotator

Add source location (file:line) to all queries:

```ruby
# config/initializers/pg_reports.rb
PgReports.configure do |config|
  # Enable the query annotator (opt-in)
  config.annotate_queries = Rails.env.development?
end
```

Optionally, include controller info:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include PgReports::QueryAnnotator::ControllerRuntime
end
```

Now your query reports will show a **source** column with file:line and controller#action info!

## Available Reports

### Queries (requires pg_stat_statements)

| Method | Description |
|--------|-------------|
| `slow_queries` | Queries with high mean execution time |
| `heavy_queries` | Most frequently called queries |
| `expensive_queries` | Queries consuming most total time |
| `missing_index_queries` | Queries potentially missing indexes |
| `low_cache_hit_queries` | Queries with poor cache utilization |
| `all_queries` | All query statistics |
| `reset_statistics!` | Reset pg_stat_statements data |

### Indexes

| Method | Description |
|--------|-------------|
| `unused_indexes` | Indexes rarely or never scanned |
| `duplicate_indexes` | Redundant indexes |
| `invalid_indexes` | Indexes that failed to build |
| `missing_indexes` | Tables potentially missing indexes |
| `index_usage` | Index scan statistics |
| `bloated_indexes` | Indexes with high bloat |
| `index_sizes` | Index disk usage |

### Tables

| Method | Description |
|--------|-------------|
| `table_sizes` | Table disk usage |
| `bloated_tables` | Tables with high dead tuple ratio |
| `vacuum_needed` | Tables needing vacuum |
| `row_counts` | Table row counts |
| `cache_hit_ratios` | Table cache statistics |
| `seq_scans` | Tables with high sequential scans |
| `recently_modified` | Tables with recent activity |

### Connections

| Method | Description |
|--------|-------------|
| `active_connections` | Current database connections |
| `connection_stats` | Connection statistics by state |
| `long_running_queries` | Queries running for extended period |
| `blocking_queries` | Queries blocking others |
| `locks` | Current database locks |
| `idle_connections` | Idle connections |
| `kill_connection(pid)` | Terminate a backend process |
| `cancel_query(pid)` | Cancel a running query |

### System

| Method | Description |
|--------|-------------|
| `database_sizes` | Size of all databases |
| `settings` | PostgreSQL configuration |
| `extensions` | Installed extensions |
| `activity_overview` | Current activity summary |
| `cache_stats` | Database cache statistics |
| `pg_stat_statements_available?` | Check if extension is ready |
| `enable_pg_stat_statements!` | Create the extension |

## pg_stat_statements Setup

For query analysis, you need to enable `pg_stat_statements`:

1. Edit `postgresql.conf`:
   ```
   shared_preload_libraries = 'pg_stat_statements'
   pg_stat_statements.track = all
   ```

2. Restart PostgreSQL:
   ```bash
   sudo systemctl restart postgresql
   ```

3. Create extension (via dashboard or console):
   ```ruby
   PgReports.enable_pg_stat_statements!
   ```

## Report Object

Every method returns a `PgReports::Report` object:

```ruby
report = PgReports.slow_queries

report.title         # "Slow Queries (mean time >= 100ms)"
report.data          # Array of hashes
report.columns       # Column names
report.size          # Row count
report.empty?        # Boolean
report.generated_at  # Timestamp

# Output formats
report.to_text       # Plain text table
report.to_markdown   # Markdown table
report.to_html       # HTML table
report.to_csv        # CSV
report.to_a          # Raw data

# Actions
report.display                  # Print to STDOUT
report.send_to_telegram         # Send as message
report.send_to_telegram_as_file # Send as file attachment

# Enumerable
report.each { |row| puts row }
report.map { |row| row["query"] }
report.select { |row| row["calls"] > 100 }
```

## Web Dashboard

The dashboard provides:

- 📊 Overview of all report categories
- ⚡ One-click report execution
- 🔍 Expandable rows for full query text
- 📋 Copy query to clipboard
- 📥 Download in multiple formats
- 📨 Send to Telegram
- 🔧 pg_stat_statements management

### Authentication

```ruby
PgReports.configure do |config|
  # HTTP Basic Auth
  config.dashboard_auth = -> {
    authenticate_or_request_with_http_basic do |user, pass|
      user == ENV["ADMIN_USER"] && pass == ENV["ADMIN_PASS"]
    end
  }

  # Or use Devise
  config.dashboard_auth = -> {
    redirect_to main_app.root_path unless current_user&.admin?
  }
end
```

## Telegram Integration

1. Create a bot via [@BotFather](https://t.me/BotFather)
2. Get your chat ID (add [@userinfobot](https://t.me/userinfobot) to get it)
3. Configure:

```ruby
PgReports.configure do |config|
  config.telegram_bot_token = "123456:ABC-DEF..."
  config.telegram_chat_id = "-1001234567890"
end
```

4. Send reports:

```ruby
PgReports.slow_queries.send_to_telegram
PgReports.health_report.send_to_telegram_as_file
```

## Development

```bash
# Clone the repo
git clone https://github.com/yourusername/pg_reports
cd pg_reports

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments

Inspired by [rails-pg-extras](https://github.com/pawurb/rails-pg-extras) and built with ❤️ for the Rails community.
