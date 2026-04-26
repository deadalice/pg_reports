# Trying Grafana + Prometheus locally without Docker

This guide walks through the simplest non-Docker setup on Linux / WSL2 / macOS — two single-binary downloads, no system services, no root, no Docker daemon. Intended for developers who want to verify the [Grafana integration](grafana.md) on their laptop before deploying anything.

For production deployment, refer to your existing Prometheus / Grafana infrastructure docs — the gem-side configuration is identical regardless of how you run them.

## 1. Run Prometheus standalone

Download the tarball ([releases](https://prometheus.io/download/)), extract, and run it from a working directory:

```bash
mkdir -p ~/grafana-test && cd ~/grafana-test
curl -L https://github.com/prometheus/prometheus/releases/download/v2.54.1/prometheus-2.54.1.linux-amd64.tar.gz | tar xz
cd prometheus-2.54.1.linux-amd64
```

Drop a minimal `prometheus.yml` next to the binary:

```yaml
global:
  scrape_interval: 60s

scrape_configs:
  - job_name: pg_reports
    metrics_path: /pg_reports/metrics   # change to match your Engine mount point
    static_configs:
      - targets: ["localhost:3000"]     # your Rails app
    # If you set grafana_metrics_token:
    # authorization:
    #   credentials: "your-token-here"
```

Start it:

```bash
./prometheus --config.file=prometheus.yml
```

It listens on http://localhost:9090. Open the **Status → Targets** page — your `pg_reports` target should be UP. The **Graph** tab lets you query `pg_reports_issues` directly.

> [!TIP]
> Run Prometheus with `--web.enable-lifecycle` if you want to reload `prometheus.yml` without restarting:
> ```bash
> ./prometheus --config.file=prometheus.yml --web.enable-lifecycle
> # later, after editing the config:
> curl -X POST http://localhost:9090/-/reload
> ```

## 2. Run Grafana standalone

Download the tarball ([downloads](https://grafana.com/grafana/download?edition=oss&platform=linux)) and run it on a different port (Rails owns 3000):

```bash
cd ~/grafana-test
curl -L https://dl.grafana.com/oss/release/grafana-11.2.0.linux-amd64.tar.gz | tar xz
cd grafana-v11.2.0    # IMPORTANT: cd into the extracted dir — Grafana resolves
                      # conf/defaults.ini relative to pwd and refuses to start otherwise
GF_SERVER_HTTP_PORT=3001 ./bin/grafana server
```

If you'd rather start it from a different working directory, pass `--homepath` explicitly:

```bash
GF_SERVER_HTTP_PORT=3001 ./grafana-v11.2.0/bin/grafana server --homepath=$(pwd)/grafana-v11.2.0
```

Open http://localhost:3001, log in as `admin` / `admin`, change the password (or skip).

## 3. Wire it up

1. **Add the datasource:** Connections → Data sources → **Add data source** → **Prometheus**. URL: `http://localhost:9090`. Save & test.
2. **Generate the dashboard** in your Rails app:
   ```bash
   bundle exec rake pg_reports:grafana:dashboard
   # writes pg_reports.json in pwd; override with OUTPUT=/tmp/x.json
   ```
3. **Import it:** Dashboards → New → Import → upload `pg_reports.json`. Grafana will ask which Prometheus datasource to bind — pick the one you added in step 1.

Within one scrape interval (≤60s) panels start filling in. If you don't have real data yet, hit the dashboard's report pages first to populate the cache, then trigger a manual scrape from Prometheus' targets page.

## Troubleshooting

- **`Grafana-server Init Failed: Could not find config defaults`** — you launched the binary from outside its extracted directory. Either `cd` into `grafana-vX.Y.Z` first, or pass `--homepath=$(pwd)/grafana-vX.Y.Z`.
- **Target down in Prometheus** — your Rails app isn't reachable. Curl your actual mount path manually: `curl -s localhost:3000/<mount>/metrics | head`. Find it with `bin/rails routes -g pg_reports | grep metrics` if unsure.
- **Empty panels** — datasource UID mismatch. Re-import and pick the correct Prometheus.
- **WSL2 + browser on Windows** — `localhost` works in modern WSL2 thanks to port forwarding. If it doesn't, run `ip addr show eth0` inside WSL and use that IP instead. Or `wsl --shutdown` from PowerShell to refresh the mapping.
- **Authorization errors after setting `grafana_metrics_token`** — the bearer header is `Authorization: Bearer <token>`. In Prometheus' config, that's `authorization.credentials` (the `Bearer` prefix is added automatically).
- **Rake task can't find favorites** — pass `FAVORITES=slow_queries,unused_indexes` inline, or set `PgReports.config.grafana_favorites` in `config/initializers/pg_reports.rb`.

For a more permanent setup, the same binaries can be wrapped in `systemd` units or supervised by `tmux`/`screen` — but for "does my dashboard look right?", running them in two terminal tabs is genuinely the fastest path.
