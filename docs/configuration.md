# Configuration

This document is the full reference for every option PgReports exposes.

All options are set inside `PgReports.configure { |config| ... }` (typically in `config/initializers/pg_reports.rb`). Everything is optional — PgReports works out of the box once mounted. ENV-defaulted options are noted next to the option name.

## Table of contents

- [Security model](#security-model)
- [Multi-database support](#multi-database-support)
- [Quick-start example](#quick-start-example)
- [pg_stat_statements setup](#pg_stat_statements-setup)
- [Query analysis thresholds](#query-analysis-thresholds)
- [Index thresholds](#index-thresholds)
- [Table thresholds](#table-thresholds)
- [Output](#output)
- [Dashboard authentication](#dashboard-authentication)
- [Locale & external fonts](#locale--external-fonts)
- [Raw query execution (EXPLAIN ANALYZE / Execute Query)](#raw-query-execution-explain-analyze--execute-query)
- [Migration creation](#migration-creation)
- [Query source tracking (Rails QueryLogs / Marginalia)](#query-source-tracking-rails-querylogs--marginalia)
- [SQL Query Monitor](#sql-query-monitor)
- [Telegram integration](#telegram-integration)
- [Grafana / Prometheus exporter](#grafana--prometheus-exporter)

---

## Security model

PgReports is a privileged operations tool — it reads pg_stat_statements, can execute arbitrary SELECTs, can write Rails migrations, and can send report content to Telegram. **Treat the dashboard as a database admin console.**

### Authentication is opt-in

The dashboard ships **without authentication**. In production you must either:

- Set `config.dashboard_auth = -> { ... }` (HTTP Basic, Devise, etc.) — runs as a `before_action`. See [Dashboard authentication](#dashboard-authentication).
- Or gate the route at the host app level (e.g. `authenticate :user, ->(u) { u.admin? } { mount ... }`).

A dashboard reachable without auth on a real database is a security incident waiting to happen.

### CSRF protection

Enabled by default (`protect_from_forgery with: :exception`) on the dashboard controller. The dashboard's forms include `authenticity_token` and XHR uses `X-CSRF-Token`. If you reverse-proxy or wrap the dashboard, preserve standard Rails CSRF behavior.

### Privileged operations are off by default

| Operation | Flag | Default |
|---|---|---|
| Execute arbitrary SELECT (`Execute Query`, `EXPLAIN ANALYZE`) | `allow_raw_query_execution` | `false` |
| Write Ruby files into `db/migrate/` (`Generate Migration`) | `allow_migration_creation` | `Rails.env.development?` |

Both can also be controlled via `PG_REPORTS_ALLOW_RAW_QUERY_EXECUTION` and `PG_REPORTS_ALLOW_MIGRATION_CREATION` env vars.

### Raw query execution caveats

When `allow_raw_query_execution` is on, the controller validates that submitted queries:

- Are SELECT-only (case-insensitive prefix check).
- Contain no semicolons (no multi-statement).
- Do not contain `INSERT/UPDATE/DELETE/DROP/ALTER/CREATE/TRUNCATE/GRANT/REVOKE` keywords.

This is a denylist, not a sandbox. A determined attacker with raw SELECT access can still:

- Read filesystem with `pg_read_server_files()` / `pg_read_binary_file()` if the connecting role has the privilege.
- Probe other servers via `dblink()` if installed.
- Trigger expensive `EXPLAIN ANALYZE` runs (which actually run the query) for DoS.

Treat `allow_raw_query_execution = true` like a SQL console handed to whoever can reach the dashboard. **Combine with strict `dashboard_auth`.**

### What gets sent to Telegram

The Telegram delivery action sends report content (table rows, possibly including query text and source files) to api.telegram.org. Don't enable this in environments where report data could include PII or secrets unless your bot/chat is appropriately scoped.

### Logged data

The Query Monitor writes captured SQL to `query_monitor_log_file` (default `log/pg_reports.log`, JSON Lines). Captured queries can include user data in WHERE clauses. File permissions inherit from the Rails app.

---

## Multi-database support

PgReports auto-discovers all databases on the cluster the host application is connected to. The dashboard exposes a database dropdown (next to the *Status* panel header) and persists the selection in the session — **no configuration is required**.

What works without any config:

- The default `:primary` target is auto-registered from `ActiveRecord::Base.connection_db_config` on first use.
- The dropdown is populated from `pg_database` (template/no-connect databases excluded).
- Switching to a different database opens an isolated AR connection pool for `(target, database)` so the host application's pool is never disturbed; the primary target's default database keeps using `ActiveRecord::Base` directly.
- Permission errors (`PG::InsufficientPrivilege`, missing CONNECT, missing database, auth failure, too-many-connections) are translated into a banner with a remediation hint (`GRANT CONNECT ON DATABASE ... TO ...` etc.).

### Programmatic switching

Block-scoped helpers, honored by every report and by code that goes through `PgReports.config.connection`:

```ruby
PgReports.with_database("logs") do
  PgReports.table_sizes
end

PgReports.with_target(:primary, database: "analytics") do
  PgReports.slow_queries(limit: 50)
end
```

Inspection helpers:

```ruby
PgReports.list_databases       # => [{ "name" => ..., "size" => ..., "current" => true/false }, ...]
PgReports.list_targets         # => [{ name: :primary, default_database: "myapp", current: true }, ...]
PgReports.current_target_name  # => :primary
PgReports.current_database_name
```

### Adding extra targets

For setups where the dashboard should reach databases the host application is **not** connected to (separate analytics warehouse, replica with different credentials, etc.), register additional targets explicitly:

```ruby
PgReports.configure do |config|
  config.add_target :analytics,
    host:     "analytics.internal",
    user:     "pgreports_ro",
    password: ENV["PG_REPORTS_ANALYTICS_PASSWORD"],
    database: "warehouse"

  config.add_target :replica_eu, url: ENV["REPLICA_EU_DATABASE_URL"]

  # Optional — change which target is the default. Default is :primary.
  config.default_target = :primary
end
```

The spec accepts the same keys as `ActiveRecord::Base.establish_connection` (a hash, an `url:` string, or an `ActiveRecord::DatabaseConfigurations::HashConfig`).

> **Notes**
> - Schema analysis reports (`missing_validations`, `polymorphic_without_index`, `counter_cache_issues`, `soft_delete_without_scope`, `orphan_tables`) introspect Ruby models from the host application — they are most meaningful on the primary target. Running them against a different database returns rows that may not map to any model.
> - The Query Monitor subscribes to `ActiveSupport::Notifications` from the host process and observes whatever connection the host app is using; it is independent of the dashboard's database selection.

---

## Quick-start example

Drop-in initializer covering the common knobs:

```ruby
# config/initializers/pg_reports.rb
PgReports.configure do |config|
  # Telegram (optional)
  config.telegram_bot_token = ENV["PG_REPORTS_TELEGRAM_TOKEN"]
  config.telegram_chat_id   = ENV["PG_REPORTS_TELEGRAM_CHAT_ID"]

  # Thresholds
  config.slow_query_threshold_ms      = 100
  config.heavy_query_threshold_calls  = 1000
  config.expensive_query_threshold_ms = 10_000
  config.unused_index_threshold_scans = 50
  config.bloat_threshold_percent      = 20
  config.dead_rows_threshold          = 10_000

  # Output
  config.max_query_length = 200

  # Auth (optional — strongly recommended in production)
  config.dashboard_auth = -> {
    authenticate_or_request_with_http_basic do |user, pass|
      user == ENV["PG_REPORTS_USER"] && pass == ENV["PG_REPORTS_PASSWORD"]
    end
  }

  # Privacy: do not load Google Fonts (default false)
  config.load_external_fonts = false
end
```

---

## pg_stat_statements setup

Required for the **Query analysis** reports (slow queries, heavy queries, expensive queries, low-cache-hit, missing-index suggestions, etc.). Without it those reports return empty.

1. Edit `postgresql.conf`:
   ```
   shared_preload_libraries = 'pg_stat_statements'
   pg_stat_statements.track = all
   ```
2. Restart PostgreSQL: `sudo systemctl restart postgresql`
3. Create the extension — either click the button on the dashboard, or run:
   ```ruby
   PgReports.enable_pg_stat_statements!
   ```

> PgReports does **not** require the `pg_read_all_settings` role — extension availability is detected by querying `pg_extension` and probing `pg_stat_statements` directly. Works with CloudnativePG, managed databases (RDS, Cloud SQL), and other restricted environments.

## Query analysis thresholds

Used by `PgReports.slow_queries`, `heavy_queries`, `expensive_queries`, and the corresponding dashboard reports. All values are tunable per environment.

| Option | Default | Meaning |
|---|---|---|
| `slow_query_threshold_ms` | `100` | Mean execution time (ms) above which a query is "slow". |
| `heavy_query_threshold_calls` | `1000` | Total call count above which a query is "heavy". |
| `expensive_query_threshold_ms` | `10_000` | Total time (ms across all calls) above which a query is "expensive". |

## Index thresholds

| Option | Default | Meaning |
|---|---|---|
| `unused_index_threshold_scans` | `50` | Indexes with fewer scans than this are flagged as unused. |
| `inefficient_index_threshold_ratio` | `10` | `idx_tup_read / idx_tup_fetch` ratio above which an index is inefficient. |

## Table thresholds

| Option | Default | Meaning |
|---|---|---|
| `bloat_threshold_percent` | `20` | Tables with more bloat (%) are flagged. |
| `dead_rows_threshold` | `10_000` | Tables with more dead tuples are flagged for vacuum. |

## Output

| Option | Default | Meaning |
|---|---|---|
| `max_query_length` | `200` | Truncate query text in displays/exports to this many characters. |

## Dashboard authentication

`dashboard_auth` is a `Proc` evaluated in the controller context as a `before_action`. Use it for HTTP Basic, Devise, or anything else that fits a `before_action`-style block:

```ruby
config.dashboard_auth = -> {
  authenticate_or_request_with_http_basic do |user, pass|
    ActiveSupport::SecurityUtils.secure_compare(user, ENV["PG_REPORTS_USER"]) &
      ActiveSupport::SecurityUtils.secure_compare(pass, ENV["PG_REPORTS_PASSWORD"])
  end
}
```

You can also gate at the routing layer with `authenticate :user` / `constraints` instead of using `dashboard_auth` — both are valid.

## Locale & external fonts

PgReports follows your application's `I18n.locale`. The dashboard ships with `en`, `ru`, and `uk`.

| Option | Default | ENV | Meaning |
|---|---|---|---|
| `load_external_fonts` | `false` | `PG_REPORTS_LOAD_EXTERNAL_FONTS` | Loads Google Fonts in the dashboard layout. Off by default for privacy. |

## Raw query execution (EXPLAIN ANALYZE / Execute Query)

The dashboard's *Execute Query* and *EXPLAIN ANALYZE* buttons are off by default. Opt in only where appropriate:

| Option | Default | ENV | Meaning |
|---|---|---|---|
| `allow_raw_query_execution` | `false` | `PG_REPORTS_ALLOW_RAW_QUERY_EXECUTION` | Enables ad-hoc query execution from the dashboard. Restricted to SELECT and uses parameterized hashing — but still treat it as privileged. |

```ruby
config.allow_raw_query_execution = Rails.env.development? || Rails.env.staging?
```

## Migration creation

The dashboard's *Generate Migration* button (visible on **Unused Indexes** and a few similar reports) writes a Ruby file into `db/migrate/`. The content is built client-side from report data. Server-side guards: filename matches `\d{14}_\w+\.rb`, target directory is `Rails.root.join("db", "migrate")`.

| Option | Default | ENV | Meaning |
|---|---|---|---|
| `allow_migration_creation` | `Rails.env.development?` | `PG_REPORTS_ALLOW_MIGRATION_CREATION` | Whether the *Generate Migration* button writes files. Disable in any environment where the dashboard might be reachable to unauthenticated users — anyone who can hit `/create_migration` can write arbitrary Ruby to `db/migrate/` and gain RCE on the next `rails db:migrate`. |

```ruby
config.allow_migration_creation = false  # disable everywhere — copy the suggested migration manually
```

## Query source tracking (Rails QueryLogs / Marginalia)

PgReports parses query annotations to display **where each query originated**. Configure on the Rails side, not on PgReports:

- **Rails 7.0+**: `ActiveRecord::QueryLogs` (built-in).
- **Older Rails**: install [Marginalia](https://github.com/basecamp/marginalia). PgReports auto-detects both formats.

Minimal setup:

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags = [:controller, :action]
```

To surface **file path + line number** so source links jump to the actual call site (not just the controller):

```ruby
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags = [
  :controller,
  :action,
  :job,
  {
    source_location: -> {
      ignore = %r{/(gems|active_record|active_support|active_model|railties|
                    action_controller|action_view|action_pack|action_dispatch|
                    rack|core_ext|relation|associations|scoping|connection_adapters)/}x
      loc = caller_locations.find { |l| !l.path.match?(ignore) }
      "#{loc.path}:#{loc.lineno}" if loc
    }
  }
]
```

PgReports recognizes the `source_location` tag and splits it into `file` and `line` columns in the dashboard.

## SQL Query Monitor

Live capture of `sql.active_record` events from the host process. Filtered to exclude framework / SCHEMA / CACHE / pg_reports' own queries.

| Option | Default | Meaning |
|---|---|---|
| `query_monitor_log_file` | `Rails.root.join("log", "pg_reports.log")` | Path to JSON Lines log file. Set to `nil` to disable file persistence. |
| `query_monitor_max_queries` | `100` | Size of the in-memory ring buffer. |
| `query_monitor_backtrace_filter` | excludes `gems`/`ruby`/`railties` paths | `Proc` taking a `Thread::Backtrace::Location`, returning `true` to keep the frame, `false` to drop it. Used when picking the source location for each query. |

```ruby
config.query_monitor_log_file        = Rails.root.join("log", "custom_monitor.log")
config.query_monitor_max_queries     = 200
config.query_monitor_backtrace_filter = ->(loc) {
  !loc.path.match?(%r{/(gems|ruby|railties)/})
}
```

## Telegram integration

| Option | Default | ENV | Meaning |
|---|---|---|---|
| `telegram_bot_token` | `nil` | `PG_REPORTS_TELEGRAM_TOKEN` | Bot token from [@BotFather](https://t.me/BotFather). |
| `telegram_chat_id` | `nil` | `PG_REPORTS_TELEGRAM_CHAT_ID` | Chat or channel ID. Obtain via [@userinfobot](https://t.me/userinfobot). |

Reports under ~50 rows go as a message; larger ones are sent as a file attachment.

```ruby
PgReports.slow_queries.send_to_telegram
PgReports.health_report.send_to_telegram_as_file
```

The optional `telegram-bot-ruby` gem activates the integration:

```ruby
# Gemfile
gem "telegram-bot-ruby"
```

## Grafana / Prometheus exporter

Exposes selected reports at `<mount_point>/metrics` in Prometheus exposition format. Severity (`ok` / `warning` / `critical`) is derived automatically from the thresholds defined in [`Dashboard::ReportsRegistry::REPORT_CONFIG`](../lib/pg_reports/dashboard/reports_registry.rb).

| Option | Default | ENV | Meaning |
|---|---|---|---|
| `grafana_favorites` | `[]` | — | Reports to expose. Array of keys, or a Hash with per-report options (`{ slow_queries: { limit: 20 } }`). |
| `grafana_metrics_token` | `nil` | `PG_REPORTS_METRICS_TOKEN` | Bearer token required at the metrics endpoint. `nil` disables auth — only safe behind a private network. |
| `grafana_cache_ttl` | `60` | — | Cache TTL (seconds) for collected reports. **Always set ≥ scrape interval** to avoid hammering the database. |

```ruby
PgReports.configure do |config|
  config.grafana_favorites = [
    :slow_queries,
    :unused_indexes,
    :bloated_tables,
    :missing_validations
  ]
  config.grafana_metrics_token = ENV["PG_REPORTS_METRICS_TOKEN"]
  config.grafana_cache_ttl     = 60
end
```

Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: pg_reports
    metrics_path: /pg_reports/metrics
    scrape_interval: 60s
    authorization: { credentials: "${PG_REPORTS_METRICS_TOKEN}" }
    static_configs:
      - targets: ["app.internal:3000"]
```

> **Warning**
> Without `grafana_cache_ttl ≥ scrape_interval`, Prometheus's default 15s scrape against expensive reports like `missing_validations` will DDoS your own database.

The exporter also emits a `pg_reports_row` series per report row (each column becomes a Prometheus label), so the auto-generated dashboard can show a **table panel** with the actual rows that need fixing — not just an aggregate count.

Generate a matching Grafana dashboard:

```bash
bundle exec rake pg_reports:grafana:dashboard
# writes pg_reports.json in pwd; then Dashboards → Import in Grafana
```

See [docs/grafana.md](grafana.md) for the full integration guide and [docs/grafana-local-setup.md](grafana-local-setup.md) for a local Prometheus + Grafana setup without Docker.
