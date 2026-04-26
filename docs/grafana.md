# Grafana / Prometheus integration

PgReports can expose selected reports as Prometheus metrics, so you can graph and alert on them in Grafana — including the Rails-aware schema-analysis reports (`missing_validations`, `polymorphic_without_index`, `counter_cache_issues`, `orphan_tables`, etc.) that pure SQL extractors cannot reproduce.

> **A note on URLs.** Throughout this document the metrics endpoint is shown as `/pg_reports/metrics`. That path is just the default mount point + `metrics` — it changes with however you mounted the Engine. If you wrote `mount PgReports::Engine, at: "/admin/db"`, your endpoint is `/admin/db/metrics`. Run `bin/rails routes -g pg_reports` to confirm. The Prometheus scrape config and any `curl` examples below need to use **your** mount path. The generated Grafana dashboard JSON itself is mount-point-agnostic — PromQL queries do not reference HTTP paths.

> [!NOTE]
> Want to try it locally without Docker? See [docs/grafana-local-setup.md](grafana-local-setup.md) for a step-by-step guide using two single-binary downloads.

## Why use this instead of a SQL extractor

A traditional approach is to point Grafana directly at PostgreSQL with the built-in datasource and run handwritten queries. That works for system metrics (`pg_stat_database`, `pg_stat_user_tables`), but it has two limitations PgReports solves:

1. **Rails-aware reports require Rails introspection.** Reports under the `schema_analysis` category (missing model validations, polymorphic associations without composite indexes, counter caches whose target column is missing, soft-delete columns without scopes, orphan tables without models) need to inspect `ActiveRecord::Base.descendants` and Rails reflections. They cannot be expressed as SQL.
2. **Thresholds and severity already live in the gem.** [`REPORT_CONFIG`](../lib/pg_reports/dashboard/reports_registry.rb) defines warning/critical cutoffs for every actionable report. The exporter reuses them so you do not maintain thresholds twice.

For purely database-side metrics (`pg_database_size`, cache hit ratios at the database level) the standard `postgres_exporter` is still the right tool.

## What the exporter emits

For each report in `grafana_favorites`, the endpoint emits six gauges:

| Metric | Labels | Meaning |
|---|---|---|
| `pg_reports_issues` | `report`, `severity` | Row count grouped by severity (`ok` / `warning` / `critical`) derived from thresholds |
| `pg_reports_rows` | `report` | Total rows the report returned |
| `pg_reports_run_seconds` | `report` | Wall time taken to collect the report (cache misses only) |
| `pg_reports_last_run_timestamp` | `report` | Unix timestamp of the last successful collection |
| `pg_reports_up` | `report`, `error` (only on failures) | `1` if the report ran, `0` if it raised |
| `pg_reports_row` | `report`, `row`, **+ each row column as a label** | One series per row of the report — the actual rows you need to fix. Drives Grafana table panels via the "Labels to fields" transformation. |

Severity rules:

- A row is `critical` if any threshold field hits the critical bound, otherwise `warning` if any field hits the warning bound, otherwise `ok`.
- Thresholds marked `inverted: true` (e.g. `cache_hit_ratio`) treat **lower** values as worse.
- Reports without thresholds (informational lists) report every row as `ok`.

`pg_reports_row` rules:

- One series per row, with each row column promoted to a Prometheus label.
- Column names are sanitised to `[a-zA-Z_][a-zA-Z0-9_]*`. Reserved names (`report`, `severity`, `row`, `error`) are dropped.
- `nil` values and values longer than 200 chars are skipped (keeps query text out of labels).
- Cardinality is bounded by your reports' `limit:` option — keep it sane (≤ 100 per report).

Example payload:

```
# HELP pg_reports_issues Number of rows by severity for the report
# TYPE pg_reports_issues gauge
pg_reports_issues{report="slow_queries",severity="ok"} 12
pg_reports_issues{report="slow_queries",severity="warning"} 3
pg_reports_issues{report="slow_queries",severity="critical"} 1
# HELP pg_reports_up Whether collection succeeded (1) or failed (0)
# TYPE pg_reports_up gauge
pg_reports_up{report="slow_queries"} 1
# HELP pg_reports_row One series per row of the report (drives Grafana table panels). Each row column becomes a label.
# TYPE pg_reports_row gauge
pg_reports_row{report="unused_indexes",row="0",index_name="idx_users_email",schemaname="public",table_name="users",idx_scan="0"} 1
pg_reports_row{report="unused_indexes",row="1",index_name="idx_orders_uuid",schemaname="public",table_name="orders",idx_scan="3"} 1
```

## Configuration

```ruby
# config/initializers/pg_reports.rb
PgReports.configure do |config|
  # Pick which reports to expose. Strings or symbols both work.
  config.grafana_favorites = [
    :slow_queries,
    :unused_indexes,
    :bloated_tables,
    :missing_validations,
    :polymorphic_without_index,
    :orphan_tables
  ]

  # Optional bearer token — when set, /metrics requires
  #   Authorization: Bearer <token>
  config.grafana_metrics_token = ENV["PG_REPORTS_METRICS_TOKEN"]

  # Default cache TTL (seconds) for collected reports.
  # Prometheus scrape interval should be <= TTL for stable values.
  config.grafana_cache_ttl = 60
end
```

### Per-report options

Pass a Hash instead of an Array when you need finer control:

```ruby
config.grafana_favorites = {
  slow_queries:        { limit: 20, ttl: 60 },
  unused_indexes:      { limit: 50 },
  missing_validations: { ttl: 1.hour },                 # heavy: don't recompute every scrape
  polymorphic_without_index: { ttl: 1.hour },
  index_sizes:         { expose_rows: false }           # noisy informational list
}
```

Recognised options:

- `limit` — forwarded to the underlying report method (only reports that accept `limit:`).
- `ttl` — overrides `grafana_cache_ttl` for that one report.
- `expose_rows` — when `false`, suppresses `pg_reports_row` for this report (you keep the aggregate metrics but skip per-row labels). Useful for reports with very wide rows or high cardinality.

## Mounting the endpoint

If you already mount the dashboard, the metrics route comes for free:

```ruby
# config/routes.rb
mount PgReports::Engine, at: "/pg_reports"
# => GET /pg_reports/metrics

# Custom path? The endpoint follows your mount point:
mount PgReports::Engine, at: "/rails/pg_reports"
# => GET /rails/pg_reports/metrics
```

Verify the actual path:

```bash
bin/rails routes -g pg_reports | grep metrics
```

You probably do **not** want the dashboard exposed in production but the metrics endpoint open. Two patterns:

**1. Dashboard behind auth, metrics behind token.** Mount once and rely on `dashboard_auth` for the UI plus `grafana_metrics_token` for `/metrics`:

```ruby
PgReports.configure do |config|
  config.dashboard_auth = -> {
    authenticate_or_request_with_http_basic { |u, p| u == ENV["PG_REPORTS_USER"] && p == ENV["PG_REPORTS_PASSWORD"] }
  }
  config.grafana_metrics_token = ENV["PG_REPORTS_METRICS_TOKEN"]
end
```

The `dashboard_auth` proc only runs in `DashboardController`; `MetricsController` has its own bearer-token check.

**2. Different mounts per environment.**

```ruby
mount PgReports::Engine, at: "/pg_reports" if Rails.env.development?
get "/internal/pg_reports/metrics", to: "pg_reports/metrics#show"
```

## Auto-generated dashboard

The gem can emit a ready-to-import Grafana dashboard JSON from the same `grafana_favorites` you configured for the exporter, so the panels match the metrics you expose without manual wiring.

```bash
# Default — writes pg_reports.json in pwd, uses PgReports.config.grafana_favorites
bundle exec rake pg_reports:grafana:dashboard

# Override favorites without touching the initializer (handy for first-time tries)
FAVORITES=slow_queries,unused_indexes,missing_validations \
  bundle exec rake pg_reports:grafana:dashboard

# Customize output path / title / uid / refresh / time range
OUTPUT=/tmp/prod-pg.json TITLE="Production DB" UID=prod-pg REFRESH=30s TIME_FROM=now-24h \
  bundle exec rake pg_reports:grafana:dashboard
```

Or from Ruby:

```ruby
File.write("pg_reports.json", JSON.pretty_generate(PgReports::Grafana::DashboardBuilder.build))
```

The output is a Grafana 9+ "import" model: when you import it through the Grafana UI it will prompt you for a Prometheus datasource (`DS_PROMETHEUS`). For each favorite you get one row per category, and two panels per report:

- **Stacked timeseries** — `pg_reports_issues` split by `severity`, with `ok` green, `warning` yellow, `critical` red.
- **Table panel** — current rows of the report, populated from `pg_reports_row` and unpacked via the **Labels to fields** transformation. This is the actionable view: which indexes, which queries, which tables to fix.

Reports with no thresholds in `REPORT_CONFIG` (informational lists like `index_sizes`) still render — every row is counted as `ok`.

A bonus task writes the current `/metrics` payload to a file, useful for debugging without curl:

```bash
bundle exec rake pg_reports:grafana:metrics              # writes pg_reports.metrics
OUTPUT=/tmp/m.txt bundle exec rake pg_reports:grafana:metrics
```

## Prometheus scrape config

```yaml
scrape_configs:
  - job_name: pg_reports
    metrics_path: /pg_reports/metrics    # change this to match your Engine mount point
    scrape_interval: 60s                 # match grafana_cache_ttl
    scrape_timeout:  30s
    authorization:
      credentials: "${PG_REPORTS_METRICS_TOKEN}"
    static_configs:
      - targets: ["app.internal:3000"]
        labels:
          env: production
```

> [!CAUTION]
> **Make sure `scrape_interval` ≥ `grafana_cache_ttl`.** Otherwise some scrapes return cached values and the dataset will look spiky for no reason.

## Caching — why it matters

> [!WARNING]
> **Without caching, you can DDoS your own database.** Prometheus scrapes every 15–60 seconds by default, and some PgReports queries (`bloated_indexes`, `missing_validations`, `polymorphic_without_index`) run for seconds against `pg_stat_*` views or full schema introspection. Running them on every scrape, in production, will absolutely burn CPU and lock IO. Treat `grafana_cache_ttl` as a hard requirement, not an optimization.

The exporter wraps each report in `Rails.cache.fetch(key, expires_in: ttl)`. The key is `pg_reports/grafana/<report_key>`, so different reports cache independently and you can override `ttl` per report.

> [!IMPORTANT]
> If `Rails.cache` is the default `MemoryStore` and you run multiple Puma workers, each worker has its own cache and may run the report independently. Fine for small fleets, painful at scale. For multi-worker deployments, use `MemCacheStore` or `RedisCacheStore` so all workers share one cache entry per report.

Set conservative TTLs for heavy reports:

```ruby
config.grafana_favorites = {
  missing_validations:       { ttl: 1.hour },   # full app schema scan
  polymorphic_without_index: { ttl: 1.hour },
  bloated_indexes:           { ttl: 10.minutes }
}
```

## Failure handling

If a report raises (missing extension, broken connection, schema change), the exporter:

- Sets `pg_reports_up{report="…",error="ErrorClassName"} 0` for that report.
- **Does not abort the rest of the payload** — sibling reports keep working.
- Skips emitting `pg_reports_rows` / `pg_reports_issues` / `pg_reports_row` for the failed report so you don't graph stale-or-zero values.

Recommended Grafana alert:

```
alert: PgReportsExporterDown
expr: max(pg_reports_up) by (report) == 0
for: 10m
labels: { severity: warning }
annotations:
  summary: "pg_reports collector failing for {{ $labels.report }}"
```

## Security notes

- The bearer-token check uses `ActiveSupport::SecurityUtils.secure_compare` over SHA-256 digests, so it is timing-safe and accepts arbitrary token lengths.
- An empty/nil `grafana_metrics_token` **disables** the check — set one in production.
- The exporter calls **only** the configured favorites. Even if an attacker reaches `/metrics` with a valid token, they can't trigger arbitrary reports through this endpoint.
- `pg_reports_row` does include row data as labels. The exporter strips `nil` values and any value over 200 chars (this filters out long query text), but identifier columns like `table_name`, `index_name`, or `column_name` are exposed verbatim. If you treat schema names as sensitive, set `expose_rows: false` for those reports — you'll still get aggregate counts.

## Suggested favorites by use case

**Performance dashboard:**
```ruby
[:slow_queries, :expensive_queries, :missing_index_queries, :temp_file_queries,
 :bloated_indexes, :bloated_tables, :seq_scans]
```

**Schema/code-quality dashboard (the unique-to-pg_reports angle):**
```ruby
[:missing_validations, :polymorphic_without_index, :counter_cache_issues,
 :soft_delete_without_scope, :orphan_tables, :always_null_columns]
```

**Operational dashboard:**
```ruby
[:active_connections, :long_running_queries, :blocking_queries,
 :pool_saturation, :connection_churn, :wraparound_risk]
```

## Sample PromQL

```promql
# All critical issues across favorites
sum by (report) (pg_reports_issues{severity="critical"})

# Issues over time per report
sum by (report, severity) (pg_reports_issues)

# How long since the exporter last collected each report
time() - pg_reports_last_run_timestamp

# Rows of a specific report (used by the auto-generated table panel)
pg_reports_row{report="unused_indexes"}
```

## Limitations

This is the first stable cut. Things deliberately not included yet:

- **Histograms.** All metrics are gauges. If you want a histogram of `slow_queries` durations, derive it in Prometheus from the per-report aggregate.
- **Templating variables.** The generated dashboard does not yet expose a `$report` variable — each panel hardcodes its report key. Good enough for a fixed favorites list; less convenient for very large fleets.
- **Stable metric format guarantee.** Until 1.0, the exporter is marked experimental and the metric names / label set may change in minor versions.

If any of these matter for your setup, open an issue.
