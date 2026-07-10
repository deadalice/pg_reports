# Standalone mode

Run the PgReports dashboard on its own — no host Rails app to mount it in. It boots a minimal Rails application that mounts the engine at `/` and serves it over HTTP, straight from the gem's root folder. Most of what the dashboard does inside a host app (multi-database switching, EXPLAIN ANALYZE, SQL Console, exports) works unchanged, because the connection you point it at is auto-registered as the `:primary` target. The **SQL Query Monitor is the one exception** — see [Security](#security) below.

## Quick start

```bash
./bin/pg_reports server              # from a checkout — no `bundle exec` needed
bundle exec pg_reports server        # or, when the gem is installed
bundle exec rake pg_reports:server   # the rake equivalent
```

By default it listens on **port 4000**, binds to **127.0.0.1**, and mounts the dashboard at **`/`**. Open <http://localhost:4000>.

## Connecting to a database

The connection is resolved in this order:

1. `--database-url` flag
2. `DATABASE_URL` environment variable
3. libpq-style env vars: `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`

```bash
# Explicit URL
DATABASE_URL=postgres://user:pass@localhost/myapp bundle exec pg_reports server
./bin/pg_reports server --database-url postgres://user:pass@db.internal/analytics

# libpq env vars (PGDATABASE defaults to "postgres", PGUSER to your OS user)
PGDATABASE=myapp PGUSER=me PGPASSWORD=secret ./bin/pg_reports server
```

Connecting to the `postgres` maintenance database is a good default: the dashboard's database dropdown then lets you switch to any database on the cluster without restarting.

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `-p`, `--port PORT` | `4000` | Port to listen on |
| `-b`, `--host HOST` | `127.0.0.1` | Interface to bind |
| `-m`, `--mount PATH` | `/` | Path to mount the dashboard at |
| `-d`, `--database-url URL` | — | PostgreSQL connection URL |
| `-s`, `--server NAME` | auto | Web server to use (`puma`, `webrick`, …) |
| `-c`, `--config PATH` | auto | Ruby config file (default: `./pg_reports.rb` or `config/pg_reports.rb`) |
| `--[no-]allow-raw-query-execution` | off | Allow raw SQL / `EXPLAIN ANALYZE` from the dashboard |
| `--[no-]allow-migration-creation` | off* | Allow the dashboard to write files into `db/migrate/` |
| `--[no-]external-fonts` | off | Load Google Fonts in the dashboard layout |
| `-h`, `--help` | | Show help |
| `-v`, `--version` | | Show version |

<sub>* `allow-migration-creation` defaults on only inside a Rails development host; standalone has no host, so it is off unless enabled.</sub>

```bash
./bin/pg_reports server --port 8080 --host 0.0.0.0 --mount /pg
./bin/pg_reports server --allow-raw-query-execution
```

## Configuration

Every setting has three layers, in increasing order of precedence:

1. **Environment variables** — `PG_REPORTS_*` (e.g. `PG_REPORTS_ALLOW_RAW_QUERY_EXECUTION`, `PG_REPORTS_LOAD_EXTERNAL_FONTS`, `PG_REPORTS_METRICS_TOKEN`). Read when the process boots.
2. **Config file** — a plain Ruby file that calls `PgReports.configure`. Loaded from `--config PATH`, or auto-detected as `./pg_reports.rb` then `config/pg_reports.rb` in the working directory. This is the way to set **everything** — thresholds, Telegram, Grafana favorites, even the `dashboard_auth` proc — none of which have a flag.
3. **CLI flags** — the security/privacy toggles in the table above. These win over both the file and the environment.

```bash
# Explicit config file, plus a flag override on top
./bin/pg_reports server --config ./my_pg_reports.rb --no-allow-raw-query-execution

# The rake task honors CONFIG=
CONFIG=config/pg_reports.rb bundle exec rake pg_reports:server
```

A config file looks exactly like a Rails initializer:

```ruby
# pg_reports.rb
PgReports.configure do |config|
  config.allow_raw_query_execution = true
  config.slow_query_threshold_ms   = 200
  config.max_query_length          = 500
  config.load_external_fonts       = true

  # Anything the flags don't cover:
  config.dashboard_auth = ->(user, pass) { pass == ENV["DASH_PASS"] }
  config.telegram_bot_token = ENV["PG_REPORTS_TELEGRAM_TOKEN"]
end
```

So yes — standalone mode reads a config file, and it can express any setting the mounted engine can.

## Web server & dependencies

Standalone mode adds **no runtime dependencies** to the gem:

- `rack` and `rackup` already ship transitively via `actionpack` / `railties`.
- The web server is resolved at run time. The runner tries `puma`, then `webrick`, and uses whichever is installed. Force one with `--server`.
- If none is available, it prints a clear message. Install one with `gem install puma` (or add `gem "puma"` to your Gemfile).

The repository's own `Gemfile` includes `puma` in the development group so `./bin/pg_reports server` works out of the box from a checkout.

## Schema Analysis is disabled

The **Schema Analysis** category is greyed out in standalone mode. Its reports (missing validations, orphan tables, polymorphic-without-index, counter-cache issues, …) introspect the **host application's ActiveRecord models** — and standalone mode has no host app, so there are no models to compare the schema against. Rather than return misleading empty or all-orphan results, the whole category is disabled with an explanation in the UI. Every other category works unchanged. Run the dashboard mounted inside your Rails app to use Schema Analysis.

## Security

Standalone mode is intended for **local, trusted use** (a developer inspecting a database from their machine). It binds to `127.0.0.1` by default and applies no dashboard authentication. If you bind to a non-loopback interface (`--host 0.0.0.0`), put it behind your own network controls — the dashboard can run queries and, if enabled, generate migrations against the target database.

Two capabilities that can modify or read arbitrary data are **off by default** and must be turned on explicitly, via a flag or the config file:

- `--allow-raw-query-execution` — the **Run SQL**, **SQL Console**, and **EXPLAIN ANALYZE** panels.
- `--allow-migration-creation` — the **Generate Migration** button (writes to `db/migrate/`).

The **SQL Query Monitor is not available in standalone mode** — it works by subscribing to `ActiveSupport::Notifications` inside a host application's process, and standalone mode has no separate host app to subscribe to (pg_reports would just be observing its own queries, which are already filtered out). The dashboard hides the panel and its `/query_monitor/*` API returns `403 Forbidden`.

If you must expose the dashboard beyond loopback, set a `dashboard_auth` proc in a config file (see [Configuration](#configuration)).

## How it works

`PgReports::Standalone.run` builds an anonymous `Rails::Application`:

- App root is a throwaway temp directory, **not** the gem root — otherwise Rails would try to load the gem's engine `config/routes.rb` and `config/locales` as the *application's* own. The engine loads those itself, relative to its own root.
- The resolved connection is passed through `DATABASE_URL` so Rails' ActiveRecord railtie wires it up natively (no `config/database.yml` required).
- Cookie sessions + a per-boot `secret_key_base` back the dashboard's database selector and CSRF protection.
- The engine is mounted via `routes.append`, and a Rack handler (Puma/WEBrick) serves the app.
