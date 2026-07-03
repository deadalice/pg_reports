# Standalone mode

Run the PgReports dashboard on its own — no host Rails app to mount it in. It boots a minimal Rails application that mounts the engine at `/` and serves it over HTTP, straight from the gem's root folder. Everything the dashboard does inside a host app (multi-database switching, query monitor, EXPLAIN ANALYZE, exports) works unchanged, because the connection you point it at is auto-registered as the `:primary` target.

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
| `-h`, `--help` | | Show help |
| `-v`, `--version` | | Show version |

```bash
./bin/pg_reports server --port 8080 --host 0.0.0.0 --mount /pg
```

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

## How it works

`PgReports::Standalone.run` builds an anonymous `Rails::Application`:

- App root is a throwaway temp directory, **not** the gem root — otherwise Rails would try to load the gem's engine `config/routes.rb` and `config/locales` as the *application's* own. The engine loads those itself, relative to its own root.
- The resolved connection is passed through `DATABASE_URL` so Rails' ActiveRecord railtie wires it up natively (no `config/database.yml` required).
- Cookie sessions + a per-boot `secret_key_base` back the dashboard's database selector and CSRF protection.
- The engine is mounted via `routes.append`, and a Rack handler (Puma/WEBrick) serves the app.
