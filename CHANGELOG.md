# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.0] - 2026-09-16

### Changed
- **The CI matrix now resolves against committed lockfiles.** `gemfiles/*.gemfile.lock` were gitignored, so every matrix job re-resolved dependencies from scratch and drifted with whatever was newest on the day — which is how the Rails 6.1 job silently moved onto a json 3.x that ActiveSupport 6.1 cannot use, turning green builds red with no code change. Each lockfile is generated with that entry's own Ruby and pinned to the runner's `x86_64-linux` platform. The Rails 6.1 lockfile deliberately pins json 3.0.2, so the incompatibility that started this stays covered rather than being pinned away.
- **Updated `json`, `loofah` and `rails-html-sanitizer`** in the root lockfile to clear open advisories (`bundler-audit`).
- **Dashboard visual overhaul — a single design system instead of three drifting stylesheets.** The three `<style>` blocks (layout, `index`, `_show_styles`) had grown independent, conflicting copies of the same components: `.modal-close` was 28px in one and 32px in another, `.modal-small` was 360px and 420px, `.toast` and the whole `.btn` family were defined twice with different colours, and `.explain-stats` / `.explain-result` were each declared twice within one file. All shared components now live once in the layout, and the per-page blocks only hold what is genuinely page-specific. `_show_styles.html.erb` shrank from 1678 to ~1500 lines with no loss of coverage.
  - **Design tokens.** New `:root` tokens for radii (`--radius-sm`/`--radius`/`--radius-lg`), control height, shadows, fonts, and an accent-tint scale (`--amber-soft`/`--amber-line`, …) derived from the actual `--accent-*` values. Every hard-coded `rgba()`/hex tint was replaced — many were leftover Tailwind-palette values (`#ef4444`, `rgba(59,130,246,…)`) that no longer matched the accent they bordered.
  - **Fixed two undeclared variables.** `--text-tertiary` and `--accent-red` were referenced but never defined, so those rules silently fell back to inherited colour; both are now declared. Removed the unused `--accent-indigo`, `--gradient-start` and `--gradient-end`.
- **Buttons are solid, classic controls.** `.btn-primary` was a translucent tinted outline (`rgba(124,138,246,.14)` fill, accent text, accent border); it is now a filled button with white text, plus proper `:active` and `:focus-visible` states. `.btn-secondary`/`.btn-danger`/`.btn-muted`/`.btn-ghost`/`.btn-icon` share one height, radius and transition, and every variant is declared in exactly one place.
- **Status is no longer signalled by coloured left stripes.** The live metric cards carried a 3px green/amber/rose `border-left` — "healthy" was as decorated as "critical". Status now reads from the corner dot, the value colour and the sparkline, with the card's own border tinting only for warning and critical. The same treatment replaced the coloured rails and `linear-gradient` washes on EXPLAIN summary cards, problem cards and stat tiles.
  - Table problem rows used `border-left` on `<tr>`, which does not render under `border-collapse: collapse`; they now use an inset shadow on the first cell, so the marker is actually visible.
- **Sparkline colour encodes state, not identity.** Each metric drew its trend in its own hue (blue/green/purple/amber/rose), which read as decoration. All five now draw in a muted neutral, switching to amber or rose only when that metric crosses its threshold.
- **Emoji replaced with an inline SVG icon sprite.** Emoji were used as UI icons throughout — the header logo tile, category and metric icons, the settings gear, lock, play/pause, and as prefixes baked into ~48 locale strings per language (`"📋 Copy"`, `"⬇ Export"`, `"🔒 Requires pg_stat_statements"`). They rendered differently on every OS and could not be coloured. All are now stroke-drawn `<symbol>`s defined once in the layout and referenced with `<use>`, inheriting colour and size from their context. Locale strings carry text only.
- **Removed the header logo tile.** The wordmark and version carry the branding.
- **Dropped the decorative motion.** Hover lifts (`translateY(-1px/-2px)`, `translateX(4px)` plus shadow), the glassmorphism `backdrop-filter: blur()` on modals, and the pulsing animation on the static status-badge dot are gone. Non-interactive panels no longer light up in accent purple on hover.
- **Typography.** Plus Jakarta Sans → Inter, body line-height 1.6 → 1.5, and a consistent type scale for a dense dashboard. Numeric surfaces (result tables, live metric values, EXPLAIN stats) use `tabular-nums` so digits stop reflowing as values refresh.
- **Accessibility.** Added `:focus-visible` rings on buttons, inputs and textareas; icon-only buttons carry `aria-label`; decorative icons are `aria-hidden`.
- **Source locations in `.rake`, `.jbuilder`, `config.ru` and extensionless files were not recognised at all.** The client-side parser matched paths against a hardcoded extension allow-list (`rb|erb|js|ts|py|go|java`); anything outside it fell through unparsed, which silently cost it the root-stripping, the start-clipping *and* its IDE link — a `/lib/tasks/setup.rake:17` rendered as the raw absolute path, home directory included. The allow-list is gone: the matcher now takes any path followed by `:<line>`, which also fixes Windows paths (`C:\app\models\post.rb:12`) that the old `[^:]+` broke on at the drive letter. Sources that still don't parse (`PostsController#index`) are clipped from the start too, instead of having their tail cut off.
- **Source locations are shown short, and never truncated where it matters.** The badge used to print the path verbatim and clip it with `text-overflow: ellipsis` — which cuts the *end*, throwing away the file name and line and leaving only a long shared prefix. It now strips the host application's root (when the engine is mounted in one), collapses a bundled gem's install prefix to the gem's own directory (`…/lib/ruby/gems/3.4.0/gems/activerecord-8.1.3/lib/…` → `activerecord-8.1.3/lib/…`), and clips what remains from the *start*, so the line number is the last thing to go: the directory is given up first and almost entirely, and only once there is no directory left does the file name itself start losing leading characters. The badge is capped at its cell's width and clips its own overflow, so a single long unbreakable file name can no longer push the badge past the column. The directory is dimmed, the file and line are not. Standalone mode has no host-app root to strip, so it gets the gem collapse and the start-clipping. The full path is unchanged in the tooltip, the expanded row and the exports, and IDE links are still built from it.
- **"Load History (50)" is now "Load History", and is disabled when there is nothing to load.** The number was the request's page size, not a count of anything the user had; read as "50 entries are waiting". The button is also enabled only when history is actually retrievable — it reads from `config.query_monitor_log_file`, so with no log file configured (or none written yet) it could only ever no-op. `QueryMonitor#status` now reports `history_available`, and the disabled button explains why in its tooltip.
- **The report page's "Back" button moved into the breadcrumb.** It sat at the far right of the action row — away from the navigation context, and a second control doing what the "Dashboard" crumb already did. The first crumb is now the back action, with a left-arrow icon making the affordance explicit.
- **One vertical rhythm for text and code blocks.** The global `* { margin: 0 }` reset leaves prose containers with no spacing of their own, and the per-element margins that filled the gap had drifted into asymmetry — a `<pre>` inherited 1rem above (from the preceding `<p>`'s `margin-bottom`) and 0 below, so snippets floated away from their intro line and collided with the line under them. Spacing is now owned by one `> * + *` rule per container, driven by a `--flow-gap` token, with the ad-hoc `margin-bottom`/`margin-top` on each block removed.
- **One code-block definition.** The same "here is how to enable this feature" panel existed in five hand-spaced copies (`<br><br>` for paragraph breaks, `&nbsp;&nbsp;` for indentation, inline `style=` for the box) across the SQL Console, EXPLAIN, Execute Query and migration flows. All five now render through a shared `pgReportsDisabledNotice()` helper using a real `<pre class="code-block">`, so indentation is actual whitespace and every snippet in the UI is styled identically.
- **One field-label definition.** `.explain-label`, `.explain-stat-label`, `.row-detail-label`, `.problem-field-label`, `.saved-record-field-name` and `.saved-record-detail-label` were six variants of "small-caps label above a value", spread across 0.65–0.8rem, three letter-spacings and two colours. Collapsed into a single rule.

### Fixed
- **The dashboard broke out of the viewport on a phone.** The `@media (max-width: 768px)` block covered the container, the header and the report actions, and nothing else, so everything added since was laid out at desktop proportions: the breadcrumb squeezed the database selector down to a few characters, the results header packed its title and three meta items into one unwrappable row, filter labels fought their inputs for the same line, and the `.btn { flex: 1 }` in that block stretched *every* button on the page — including "Clear All", which then overran the "Saved for Comparison" title next to it. Two things pushed the page itself sideways: the Query Monitor's scope tooltip (a 320px absolutely-positioned `::after` anchored mid-row, which widened the layout viewport and dragged the fixed toast with it), and the toast's own `max-width: 26rem`, wider than the screen and pinned by `right`. The expanded-row detail was the worst of it — a two-column grid inside the horizontally scrolling results table, with its second column parked off-screen. It is now one column, pinned to the viewport with `position: sticky` so it stays readable while the table scrolls sideways under it; the generic cell rule's `overflow: hidden`, which made the cell its own scroll container and killed the sticky, is lifted for that one cell. The tooltip becomes a bottom sheet, the toast spans the screen width, and the button stretch is scoped to the page's actual action bars. Verified at 320/360/390/414/768px across the dashboard and five report pages: no page-level horizontal overflow anywhere, with only the results table scrolling sideways as intended.
- **The proxy scrollbar above a wide results table was dead space on touch.** It renders a 12px strip whose only purpose is to be dragged, and touch devices draw no scrollbar in it; it is now skipped when the pointer is coarse, where the table is dragged directly anyway.
- **Query-monitor file logging silently wrote nothing on Rails <= 7.0 with json >= 3.** The writer serialized with `#to_json`, which ActiveSupport overrides and (up to Rails 7.0) calls with json's `quirks_mode` option — removed in json 3, so it raises `ArgumentError: unknown keyword: quirks_mode`. The writer's `rescue` swallowed that by design ("don't break monitoring if the file write fails"), so the log file just stayed empty with no visible error. Serialization now goes through `JSON.generate`, json's own generator, which takes no such option. Covered by a regression spec.


- **Migration-disabled toast was hardcoded Russian** in an otherwise fully translated UI. Now goes through `errors.migration_disabled_toast` (added to all three locales).
- **Migration-disabled panel title was hardcoded English.** Now goes through `modals.migration_disabled_title` (added to all three locales).
- **Switching to a database without pg_stat_statements leaked `PG::UndefinedTable` into the UI.** The extension is created per-database, but the availability gate lived only in the dashboard template (`category_key == :queries && !@pg_stat_status[:ready]`). `show`, `run`, `download` and `send_to_telegram` never consulted it, so opening a Queries report and then switching the database ran the report anyway and rendered the driver's `relation "pg_stat_statements" does not exist LINE 11:` in the error banner. The requirement is now declared on the category (`requires: :pg_stat_statements`) and enforced in `#category_disabled_reason`, which every entry point already calls — the dashboard template now reads that same value instead of repeating the rule. The message distinguishes the two remedies: an extension that was never created here, versus one that exists but is missing from `shared_preload_libraries`. An unreachable database is left to the existing connection-error banner rather than being mislabelled as a missing extension.
- **Redirects out of an unavailable report were silent.** `show` has always redirected to the dashboard with `alert:` when a category is unavailable, but no view rendered `flash`, so the user was bounced with no explanation. The layout now renders `flash[:alert]` / `flash[:notice]`.
- **`ErrorTranslator` handles missing relations and functions** (`42P01`, `42883`). When the missing relation is one an extension provides, it names the extension and hints the `CREATE EXTENSION` instead of echoing the raw driver message. The three report endpoints route failures through the translator; the raw-SQL endpoints (SQL Console, Execute Query, EXPLAIN) still return PostgreSQL's own wording, which is what you want for a query you typed yourself.
- `ExplainAnalyzer` no longer emits a `status_icon` emoji from the analysis layer; the dashboard picks the icon from `status`.

## [0.8.2] - 2026-07-10

### Added

- **SQL Console — free-form SQL editor.** A new **SQL Console** button in the dashboard header opens a large modal with a SQL textarea (⌘/Ctrl+Enter to run) and a results table with row count and execution time. Renamed from the initial "Run Query" label, which read too similarly to the existing **▶ Run Report** button. Unlike *Execute Query* (which only ever runs server-generated, hash-cached queries — see 0.5.1 below), this accepts client-typed SQL directly, so the same SELECT-only/no-semicolon/keyword-denylist validation is applied straight to the submitted text via a new shared `enforce_select_only!` check. Gated by the existing `config.allow_raw_query_execution` flag; new `POST /run_query` endpoint.
- **Bounded statement timeout for raw query execution.** `Execute Query`, `EXPLAIN ANALYZE`, and `SQL Console` now run inside a transaction with `SET LOCAL statement_timeout`, configurable via `config.raw_query_statement_timeout_ms` (default 5000ms, `PG_REPORTS_RAW_QUERY_STATEMENT_TIMEOUT_MS`, `0` disables). Prevents a runaway or accidentally expensive query from holding a connection open indefinitely; a cancelled query now surfaces a clear "query timed out" error instead of an opaque `PG::QueryCanceled`.
- **Rate limiting for privileged dashboard endpoints.** `explain_analyze`, `execute_query`, `run_query`, and `create_migration` are now throttled per client IP via `config.raw_query_rate_limit` (default 30 requests, `PG_REPORTS_RAW_QUERY_RATE_LIMIT`) within `config.raw_query_rate_limit_window_seconds` (default 60s, `PG_REPORTS_RAW_QUERY_RATE_LIMIT_WINDOW_SECONDS`). Backed by `Rails.cache`; best-effort (not a hardened distributed limiter) and fails open if the cache is unavailable. Set `raw_query_rate_limit = nil` to disable.

### Changed

- **SQL Query Monitor is no longer shown in standalone mode.** It works by subscribing to `ActiveSupport::Notifications` in a host application's process — standalone mode has no separate host app, so the panel had nothing meaningful to monitor. The dashboard panel is now hidden and the `/query_monitor/*` endpoints return `403 Forbidden` when `PgReports.config.standalone` is true.

## [0.8.1] - 2026-07-03

### Added

- **Standalone mode — run the dashboard without a host Rails app.** A new `pg_reports server` executable (and `rake pg_reports:server` task) boots a minimal Rails application that mounts the engine at `/` and serves it on port **4000**, straight from the gem's root folder. The connection is resolved from `--database-url`, then `DATABASE_URL`, then libpq-style `PG*` env vars; flags cover `--port`, `--host`, `--mount`, and `--server`. All existing multi-database / multi-cluster switching works unchanged, since the connection registry auto-registers the standalone connection as the `:primary` target.
  - **No new runtime dependencies.** `rack` and `rackup` already ship transitively via `actionpack`/`railties`; the web server (Puma, WEBrick, …) is resolved at run time and is not a hard dependency — the runner uses whichever is installed and prints a clear message if none is.
  - New `PgReports::Standalone` module encapsulating app construction, connection resolution, and server boot.
  - `./bin/pg_reports` runs from a checkout without `bundle exec` via a soft bundler shim (activated only when a Gemfile sits next to the executable; skipped for the installed gem).
  - **[docs/standalone.md](docs/standalone.md).**
- **Dashboard footer** with links to the project on GitHub and a contact address.
- **ESC closes any open modal.** A single global handler triggers the modal's own close button, so per-modal cleanup still runs.

### Changed

- **Redesigned the pg_stat_statements status badge.** The header badge now reports four clearly distinguished states with plain-language labels instead of a raw identifier glued to an adjective (`pg_stat_statements готовий`):
  - 🟢 **Active** — monitoring works.
  - 🟡 **Preload required** — the extension exists but isn't in `shared_preload_libraries`; clicking the badge opens the setup instructions.
  - 🟡 **Extension required** — the library is loaded but the extension isn't created; clicking opens a modal with a one-click **Create extension** button.
  - 🔴 **No connection** — the database itself is unreachable.
  Warning/error badges are now clickable and self-explanatory. The redundant `?` info button and the header **Create extension** button were removed in favor of the badge-driven modals. Labels no longer use a negative "Not …" framing. Translations updated for `en` / `uk` / `ru`.
- **pg_stat_statements status detection no longer reads `shared_preload_libraries`.** That setting requires the `pg_read_all_settings` role and is unreadable by a typical monitoring user, which made the "preloaded but extension missing" state unreachable. State is now derived entirely from signals every role can observe: connectivity (`SELECT 1`), extension presence in `pg_extension`, and whether the `pg_stat_statements` view is queryable. `pg_stat_statements_status` gains a `connected:` key, and `PgReports.system.connected?` is a new public helper.
- **Primary buttons toned down.** `btn-primary` (Start monitoring, Run report, Create extension, …) switched from a solid accent fill to a subtle tinted style, so it reads as the accent action without dominating the page.
- **Live-metrics "long queries" threshold lowered from 60s to 5s** — the default the top-of-dashboard tile counts against.
- **Header/layout polish** — the status badge, settings button, and Reset button are unified to the same height; the settings button is now square; the pg_stat_statements category warning banner no longer overhangs its card; and the "scope: host application" note in the query monitor uses a real styled tooltip (hover + keyboard focus) instead of the unreliable native `title`.
- **README trimmed**: standalone, Telegram, and Grafana/Prometheus details moved to dedicated docs ([docs/standalone.md](docs/standalone.md), [docs/telegram.md](docs/telegram.md), [docs/grafana.md](docs/grafana.md)).

### Fixed

- **Query Monitor no longer records pg_reports' own queries.** Internal queries (live-metrics polling, status checks, database listing) run through `Executor`/`Target` are now tagged with a `"PgReports"` statement name, so `QueryMonitor#should_skip?` filters them by name regardless of backtrace depth. Previously the deep `ActiveSupport::Notifications` stack could push the pg_reports frames past the 30-frame backtrace scan, leaking these queries into the monitor history.
- **Dashboard requests broke when the engine is mounted at the root path** (e.g. standalone). The client base path resolved to `/`, so `fetch` URLs became `//live_metrics` — a protocol-relative URL the browser sent to a bogus host, breaking live metrics and report runs. The base now strips a trailing slash.

## [0.8.0] - 2026-05-01

### Added

- **Multi-database dashboard.** Switch between databases on the connected cluster from a dropdown in the dashboard header — no configuration required. The selected database persists across requests in the session and applies to every report on every page.
  - New `PgReports::Connection::Registry` with auto-registered `:primary` target derived from `ActiveRecord::Base.connection_db_config`. Existing setups need no changes.
  - New block-scoped APIs: `PgReports.with_target(:name, database: ...)`, `PgReports.with_database("name")`. Honored by `Executor` even when memoized inside modules — the connection is now resolved on every call rather than at construction.
  - New helpers: `PgReports.list_databases`, `PgReports.list_targets`, `PgReports.current_target_name`, `PgReports.current_database_name`.
  - New `Configuration#add_target(name, spec)` and `default_target=` for explicitly registering additional targets (host/port/user/database) when the dashboard should reach databases the host app cannot.
  - Database switching opens an isolated AR connection pool per `(target, database)` so the host application's pool is never disturbed; the primary target's default database keeps using `ActiveRecord::Base` directly.
- **Human-readable connection errors.** `PgReports::Connection::ErrorTranslator` maps `PG::Error` SQLSTATEs (`42501`, `3D000`, `28P01`, `08006`, `53300`) and AR-wrapped variants into a `{ title, detail, hint, code }` hash. Permission errors include a concrete `GRANT ...` remediation hint. The dashboard renders the translation as a banner on the index when it can't list databases.
- **Schema Analysis category gated to the primary target.** When the dashboard is pointed at a non-primary database (where the host app's models don't apply), the Schema Analysis category is greyed out with an explanation, and direct URL access redirects to the index with a flash message. Same gating extends to the JSON endpoints (`run`, `download`, `send_to_telegram`).
- **Configuration reference** moved to [docs/configuration.md](docs/configuration.md).

### Security

- **CSRF protection** is now enforced on the dashboard controller (`protect_from_forgery with: :exception`). Previously the controller inherited from `ActionController::Base` without opting in — every state-changing endpoint (`switch_database`, `switch_target`, `execute_query`, `explain_analyze`, `create_migration`, `reset_statistics`, telegram delivery, query_monitor start/stop) was reachable cross-origin from any logged-in user's browser. The dashboard already shipped `authenticity_token` in forms and `X-CSRF-Token` in XHR — only the server enforcement was missing.
- **`create_migration` is now opt-in via `config.allow_migration_creation`** (default `Rails.env.development?` to preserve prior behavior; toggleable via `PG_REPORTS_ALLOW_MIGRATION_CREATION`). The endpoint writes Ruby code into `db/migrate/`. With CSRF fixed and a denied-by-default flag, a dashboard exposed without auth no longer trivially leads to RCE on next `rails db:migrate`. Combine with `dashboard_auth` for layered defense.

## [0.7.0] - 2026-04-26

### Added

- **Experimental Grafana / Prometheus support.** Selected reports can now be exposed at `<mount_point>/metrics` in Prometheus exposition format. Severity (`ok` / `warning` / `critical`) is derived automatically from the existing `REPORT_CONFIG` thresholds, including inverted ones (`cache_hit_ratio` etc.). Per-row data is emitted as `pg_reports_row` with each row column as a label, suitable for Grafana table panels via the "Labels to fields" transformation.
  - New config: `grafana_favorites`, `grafana_metrics_token`, `grafana_cache_ttl`. Reports are cached via `Rails.cache` with a per-report TTL override to keep frequent scrapes from hammering the database.
  - New endpoint: `MetricsController` with timing-safe bearer-token auth.
  - New rake tasks: `pg_reports:grafana:dashboard` (writes a ready-to-import Grafana dashboard JSON) and `pg_reports:grafana:metrics` (prints the current metrics payload).
  - New module `PgReports::Grafana::Exporter` and `PgReports::Grafana::DashboardBuilder`.
  - Documentation: [docs/grafana.md](docs/grafana.md) (integration guide) and [docs/grafana-local-setup.md](docs/grafana-local-setup.md) (local Prometheus + Grafana setup without Docker).
  - **Note:** the metric format may change in future minor versions until 1.0.

## [0.6.2] - 2026-04-25

### Added

- **Native Rails QueryLogs source_location support** — `AnnotationParser` now recognizes the `source_location` tag emitted by `ActiveRecord::QueryLogs` and splits it into separate `:file` / `:line` fields for the dashboard's source column. Values are URL-decoded first, since Rails CGI-escapes tag values (so `%2F.../%3A19` becomes `/.../foo.rb:19`).

### Fixed

- **`counter_cache_issues` crashed/misreported on Rails 7.1+ Hash form.** `belongs_to :user, counter_cache: :col` is internally normalized to `{active: true, column: :col}` on Rails 7.1+, but the helper only handled `true` / Symbol / String — so the column came out as `Hash#inspect` (`{active: true, column: "usage_count"}`) and the suggested migration was malformed. `counter_cache_column_name` now handles all four forms (Boolean, Symbol, String, Hash with `:column` key, Hash without `:column`).
- **`polymorphic_without_index` crashed with `NoMethodError: undefined method '&' for an instance of String`** when a table had an expression index (e.g. `CREATE INDEX ON x (LOWER(email))`). PostgreSQL returns `IndexDefinition#columns` as a String for expression indexes, not an Array. Both the polymorphic check and `coverage_label` now filter out non-array indexes.

### Changed

- **README simplified** — full reports listing moved to [docs/reports.md](docs/reports.md), long sections (EXPLAIN ANALYZE, SQL Query Monitor, Connection pool analytics, IDE integration, Telegram delivery, raw query execution, source tracking) collapsed into `<details>` blocks. From 582 lines to ~340.
- **Query source tracking** documentation now leads with native `ActiveRecord::QueryLogs` (Rails 7.0+) including a `source_location` lambda example. Marginalia mentioned only as the option for Rails < 7.0.

## [0.6.1] - 2026-04-24

### Added

- **8 new reports** — 4 dead-schema/write-amplification reports plus 4 Rails-schema-consistency reports:
  - `unused_columns` (Schema Analysis) — columns with `pg_stats.n_distinct = 1`, indicating no `UPDATE` has ever changed them since creation. Strong signal that the application code no longer references the column.
  - `always_null_columns` (Schema Analysis) — nullable columns where ~100% of rows are NULL. Companion to `unused_columns` from a different angle.
  - `update_hotspots` (Tables) — tables with high `updates_per_row` (same rows rewritten repeatedly) or low `hot_update_pct` (indexed columns being updated, defeating HOT). Includes refactor guidance: split hot/cold columns, event-log tables, write batching, fillfactor tuning.
  - `unused_tables` (Tables) — tables with zero `seq_scan + idx_scan` since the last stats reset. Surfaces `db_stats_since` so you know how much history the verdict rests on.
  - `polymorphic_without_index` (Schema Analysis) — polymorphic `belongs_to` associations whose `(*_type, *_id)` pair has no composite index. With table growth, association loads turn into seq scans.
  - `counter_cache_issues` (Schema Analysis) — `belongs_to ..., counter_cache: ...` declarations whose target column is missing on the parent. Counter is silently broken — writes go nowhere, reads return nil/zero.
  - `soft_delete_without_scope` (Schema Analysis) — tables with a `deleted_at` / `discarded_at` / `archived_at` column whose model has no scope filtering soft-deleted rows. Plain queries leak deleted data into reports, indexes, exports.
  - `orphan_tables` (Schema Analysis) — DB tables with no corresponding Rails model class. Classified as `join_table_candidate` (likely legitimate HABTM), `join_model_without_class` (probably should be a model), or `legacy` (the interesting ones).
- New problem keys: `unused_column`, `always_null_column`, `hot_rows`, `low_hot_update`, `unused_table`, `polymorphic_no_index`, `counter_cache_missing_column`, `soft_delete_unprotected`, `orphan_table_legacy`.
- Full i18n for all new reports (en/ru/uk).
- **Full UI localization (en/ru/uk).** All dashboard chrome — buttons, modals, toasts, status badges, metric labels, filter labels, error messages, monitoring panels — now reads from a new `pg_reports.ui.*` locale namespace (183 keys per language). Plus three sibling namespaces resolved at access time from `Dashboard::ReportsRegistry` and `ReportDefinition#filter_parameters`:
  - `pg_reports.categories.*` — the 6 dashboard category names (Queries / Indexes / Tables / Connections / System / Schema Analysis).
  - `pg_reports.reports.<name>.{name, description}` — short name and one-line description for all 47 reports shown in the dashboard listing.
  - `pg_reports.parameters.<name>.{label, description}` plus `threshold_label`/`threshold_description` templates for filter inputs.
  Previously only the per-report long-form documentation was translated; the surrounding UI was hardcoded English regardless of `I18n.locale`.
  - Added `window.PG_REPORTS_I18N` injected by the layout (`I18n.t('pg_reports.ui').to_json`) so client-side JS strings (toasts, dynamically rendered HTML, EXPLAIN output, IDE menu, query monitor feed) all respect the active locale.
  - `<html lang>` now reflects `I18n.locale` instead of being hardcoded to `en`.
  - Controller-level error/success messages (`reset_statistics`, `live_metrics`, `explain_analyze`, `execute_query`, `create_migration`, etc.) now use `I18n.t`.

### Changed

- `module_generator` now camelizes multi-word module names (`schema_analysis` → `SchemaAnalysis`) so YAML-defined reports can live under multi-word modules. Previously only single-word modules worked via auto-generation.
- `NEW` badge moved off the seven 0.6.0 reports onto the four added in this version.

## [0.6.0] - 2026-04-11

### Added

- **7 new reports** covering previously undetected PostgreSQL problems:
  - `inefficient_indexes` — indexes with high read-to-fetch ratio indicating misaligned composite index column order
  - `fk_without_indexes` — foreign keys on child tables missing a supporting index, causing seq scans on parent DELETE/UPDATE
  - `index_correlation` — low physical correlation between index order and row order, causing excessive random I/O on range scans
  - `temp_file_queries` — queries spilling intermediate results to disk due to insufficient `work_mem` (requires pg_stat_statements)
  - `tables_without_pk` — tables missing primary keys, which breaks logical replication and causes ORM issues
  - `wraparound_risk` — transaction ID age proximity to the 2-billion wraparound limit that triggers emergency PostgreSQL shutdown
  - `checkpoint_stats` — checkpoint frequency and background writer metrics with PostgreSQL 17+ support
- **AI Prompt Export** — "Copy Prompt" button in the Export dropdown generates a ready-to-paste prompt for AI coding assistants (Claude Code, Cursor, Codex) with problem description, fix instructions, and actual report data as examples. Available for 28 actionable reports.
- **Compatibility warnings** — the gem now warns at boot if Ruby, Rails, or PostgreSQL versions are below minimum supported (Ruby 2.7, Rails 5.0, PostgreSQL 12)
- **`inefficient_index_threshold_ratio`** configuration option (default: 10) for the inefficient indexes report
- Full i18n support for all new reports in English, Russian, and Ukrainian

### Fixed

- **Critical: infinite recursion in Query Monitor with database-backed cache stores** (SolidCache, ActiveRecord Cache Store) — `handle_sql_event` called `Rails.cache.read()` on every SQL event to check `enabled` state, which with DB-backed caches generated new SQL events, creating an infinite loop. Fixed by storing monitoring state in local instance variables (`@enabled`, `@session_id`) and syncing from cache only at initialization. Added reentrancy guard as additional safety net. (Reported via [PR #7](https://github.com/deadalice/pg_reports/pull/7))
- **`checkpoint_stats` compatibility with PostgreSQL 17+** — checkpoint columns were moved from `pg_stat_bgwriter` to `pg_stat_checkpointer` with renamed columns. The report now auto-detects the PostgreSQL version and uses the appropriate query.
- **26 previously failing Query Monitor specs** now pass — tests no longer depend on `Rails.cache` availability

### Changed

- **Dashboard UI redesign** — flattened the visual style to remove typical AI-generated patterns:
  - Removed gradient buttons, gradient text on logo, backdrop blur on modals
  - Removed `translateY` hover animations on cards and buttons
  - Unified `border-radius` to 6px across all components (was 8–16px)
  - Subdued box-shadows (`0 4px 16px` instead of `0 10px 40px`)
  - Muted color palette — same CSS variables, lower saturation
  - Background warmed from `#0f1114` to `#151719`
  - Removed colored icon backgrounds from category cards
  - Report links now transparent by default (tertiary fill on hover only)
  - NEW badge restyled: tinted background instead of solid green
  - Buttons use flat solid color instead of gradients
- "Download" button renamed to "Export" with AI Prompt option added to the dropdown
- New reports tagged with `NEW` badge in the dashboard sidebar
- Query Monitor `enabled` and `session_id` public methods now return local state instead of hitting cache on every call

## [0.5.4] - 2026-02-11

### Fixed

- **Live Query Monitor critical fix for multi-process servers** - monitoring now works correctly with Puma, Unicorn, and other multi-process web servers:
  - Migrated from Singleton instance variables to Rails.cache for cross-process state sharing
  - Fixed "Monitoring not active" errors when requests hit different worker processes
  - Each process now subscribes to SQL notifications when monitoring is enabled
  - State (enabled/session_id) stored in Rails.cache with 24-hour TTL
  - Added cache helper methods with graceful error handling
  - Monitoring state now persists across all processes in multi-worker environments
  - Exclude `query_monitor.rb` itself from `query_from_pg_reports?` check to prevent false positives

### Added

- **Enhanced error handling for Query Monitor**:
  - Toast notification system with visual feedback (success/error/warning types)
  - Server errors now displayed to users with clear messages
  - Automatic monitoring stop and UI reset when errors occur
  - Smooth animations with auto-dismiss after 4 seconds

## [0.5.3] - 2026-02-11

### Fixed

- **Live Query Monitor** - fixed filtering that was too aggressive:
  - Removed `dashboard_controller.rb` from query filtering to allow monitoring user application queries
  - Now correctly shows queries from user's application even when dashboard page is active
  - Only internal pg_reports module queries are filtered (as intended)

### Added

- **IDE Integration for Live Query Monitor**:
  - Clickable source file links in query monitor now open files in IDE
  - Support for multiple IDEs: VS Code, RubyMine, IntelliJ IDEA, Cursor (with WSL variants)
  - Smart IDE selection: shows menu or opens directly if favorite IDE is set
  - IDE settings button (⚙️) in dashboard header for choosing default IDE
  - Settings persist in localStorage across all dashboard pages

## [0.5.2] - 2026-02-09

### Fixed

- **pg_stat_statements detection no longer requires `pg_read_all_settings` role**:
  - Changed `pg_stat_statements_preloaded?` to query pg_stat_statements directly instead of checking `shared_preload_libraries`
  - Fixes permission denied errors in environments like CloudnativePG where regular users lack access to `shared_preload_libraries` setting
  - Works seamlessly with Kubernetes PostgreSQL operators and managed databases with restricted permissions
  - Improved error messages in `enable_pg_stat_statements!` method

## [0.5.1] - 2026-02-09

### Added

- **Query Execution Security** - new configuration to control raw SQL execution from dashboard:
  - New config option `allow_raw_query_execution` (default: `false`)
  - Environment variable support: `PG_REPORTS_ALLOW_RAW_QUERY_EXECUTION`
  - Security documentation in README with examples and best practices
  - Configuration tests for new security setting
- **Hash-based Query Execution System** - prevents SQL injection and query tampering:
  - Backend generates SHA256 hash for each query and stores in Rails.cache (1-hour TTL)
  - Frontend sends only hash (not query text) to execution endpoints
  - Backend retrieves and validates original query by hash
  - Strict validation: only SELECT queries, no dangerous keywords, no multiple statements
  - Cache failure handling with clear error messages
  - Protection against nested SQL injection attempts
- **Enhanced Error Handling** - improved user feedback:
  - Active warning messages instead of disabled buttons when feature is off
  - Toast notifications with configuration instructions
  - Detailed error messages in modal with code examples
  - Clear messaging when Redis/cache backend is unavailable

### Changed

- **BREAKING CHANGE**: `execute_query` and `explain_analyze` endpoints now require explicit opt-in
  - Both endpoints return 403 Forbidden when `allow_raw_query_execution` is `false` (default)
  - To restore previous behavior, add to initializer: `config.allow_raw_query_execution = true`
  - **Migration path**: Users must explicitly enable this feature if they were using Query Analyzer
- **UI/UX Improvements**:
  - Query Analyzer modal size increased: width 600px→900px, height 80vh→90vh for better query visibility
  - "EXPLAIN ANALYZE", "Execute Query", and "Create Migration" buttons now show active warnings when clicked (instead of being disabled)
  - Warning messages include configuration instructions with code examples
  - Better visual feedback for disabled features
- **Query Execution Flow**:
  - `execute_query` and `explain_analyze` endpoints now accept `query_hash` parameter (instead of `query`)
  - New helper methods: `store_query_with_hash()` and `retrieve_query_by_hash()`
  - Frontend stores `data-query-hash` attribute on EXPLAIN ANALYZE buttons
  - JavaScript validation happens client-side before API calls

### Security

- **Critical Security Enhancement**: Raw SQL execution from dashboard is now **disabled by default** to prevent unauthorized data access
- **Query Tampering Prevention**: Frontend cannot modify queries - hash-based verification ensures query integrity
- **SQL Injection Protection**: Strict validation on backend prevents any non-SELECT queries or dangerous keywords
- **Multiple Statement Prevention**: Semicolon detection blocks SQL injection attempts with multiple statements
- **Cache Dependency**: Query execution temporarily disabled if Redis/cache backend is unavailable (fail-secure)
- Recommended setup: only enable in development/staging environments
- Existing safety measures (automatic LIMIT) still apply when enabled

## [0.5.0] - 2026-02-07

### Added

- **EXPLAIN ANALYZE Advanced Analyzer** - intelligent query plan analysis with problem detection:
  - New `ExplainAnalyzer` service class for parsing and analyzing EXPLAIN output
  - Color-coded node types (🟢 efficient, 🔵 normal, 🟡 potential issues)
  - Automatic problem detection:
    - Sequential scans on large tables (cost > 1000, rows > 1000)
    - High-cost operations (> 10,000)
    - Sort operations spilling to disk
    - Slow sorts (> 1 second)
    - Inaccurate row estimates (> 10x deviation)
    - Slow execution/planning times
  - Summary card with overall status (🟢 No issues / 🟡 Warnings / 🔴 Critical)
  - Problem list with detailed explanations and recommendations
  - Line-by-line plan annotations with problem indicators
  - Metric highlighting (cost, rows, time, loops)
  - Copy to clipboard functionality
- **Connection Pool Analytics** - comprehensive pool monitoring and diagnostics:
  - `pool_usage` report - real-time utilization metrics per database:
    - Active, idle, idle-in-transaction connection breakdown
    - Utilization percentage with thresholds (70% warning, 85% critical)
    - Available connection capacity calculation
  - `pool_wait_times` report - resource wait analysis:
    - Queries waiting for locks, I/O, or network operations
    - Wait event type classification (ClientRead, Lock, IO)
    - Duration tracking with severity thresholds (10s warning, 60s critical)
  - `pool_saturation` report - health warnings with recommendations:
    - Overall pool metrics with status indicators (🟢🟡🔴)
    - Automatic severity assessment per metric
    - Context-aware recommendations embedded in SQL
    - Tracks total, active, idle, idle-in-transaction, and waiting connections
  - `connection_churn` report - lifecycle and churn analysis:
    - Connection age distribution per application
    - Short-lived connection detection (< 10 seconds)
    - Churn rate percentage calculation (50% warning, 75% critical)
    - Identifies missing or misconfigured connection pooling
- Complete i18n translations (English and Russian) for all new reports
- Documentation for each report with usage patterns and nuances
- **SQL Query Monitoring** - real-time query capture and analysis:
  - New `QueryMonitor` singleton service for capturing all SQL queries via ActiveSupport::Notifications
  - Dashboard panel with start/stop controls and live query feed
  - Query capture features:
    - SQL text, execution duration (color-coded: green < 10ms, yellow < 100ms, red > 100ms)
    - Source location (file:line) with click-to-open in IDE
    - Timestamp and query name
    - Session-based tracking with unique UUIDs
  - Smart filtering:
    - Automatically excludes SCHEMA, CACHE, EXPLAIN queries
    - Filters DDL statements (CREATE, ALTER, DROP)
    - Excludes pg_reports' internal queries
    - Configurable backtrace filtering for source location extraction
  - UI features:
    - Collapsible/expandable queries (truncated to 100 chars by default)
    - Real-time updates via 2-second polling
    - Reverse chronological order (newest first)
    - Query counter with session badge
  - Persistence:
    - JSON Lines (JSONL) log format in `log/pg_reports.log`
    - Session markers (session_start/session_end)
    - In-memory circular buffer (configurable, default 100 queries)
    - Automatic log loading on dashboard open
    - Results persist after stopping monitoring
  - Export capabilities:
    - Download in TXT, CSV, or JSON formats
    - Works even after monitoring stopped
    - Includes all query metadata (timestamp, duration, source, SQL)
    - Uses hidden iframe for downloads (doesn't interrupt monitoring)
  - Configuration options:
    - `query_monitor_log_file` - custom log file path
    - `query_monitor_max_queries` - buffer size (default: 100)
    - `query_monitor_backtrace_filter` - Proc for filtering backtrace lines
  - New routes and controller actions:
    - `POST /query_monitor/start` - start monitoring
    - `POST /query_monitor/stop` - stop monitoring
    - `GET /query_monitor/status` - check monitoring status
    - `GET /query_monitor/feed` - get live query feed
    - `GET /query_monitor/history` - load queries from log file
    - `GET /query_monitor/download` - export queries
  - Comprehensive test coverage (39 unit tests + 5 integration tests)

### Changed

- **Unified status indicators** - consistent 🟢🟡🔴 emoji usage across all reports:
  - Replaced ✅ checkmark with 🟢 green circle for "good" status
  - Replaced ⚠️ warning sign with 🟡 yellow circle for "warning" status
  - Retained 🔴 red circle for "critical" status
  - Applied to EXPLAIN analyzer summary and connection pool reports
- **Simplified database filtering** - all reports now use only current database from project settings:
  - Removed database selector UI component from dashboard
  - All SQL queries now filter by `current_database()` function automatically
  - Current database name displayed in Live Monitoring header
  - Removed `database` parameter from all query reports
  - Removed `databases_list` endpoint and related routes
  - Cleaner, more focused dashboard experience
- **Optimized gem dependencies** - replaced full Rails framework dependency with specific components:
  - Now using `activesupport`, `activerecord`, `actionpack`, `railties` instead of `rails`
  - Removed unnecessary components: actioncable, actionmailer, actiontext, activejob, activestorage
  - Reduced total dependencies from 97 to 80 gems (-17.5%)
  - Faster installation and smaller footprint

## [0.4.0] - 2026-01-29

### Added

- **YAML-based Report Configuration System** - declarative report definitions:
  - Each report now defined in a single YAML file (1 file = 1 report approach)
  - Migrated all 31 reports from Ruby methods to YAML format
  - New classes: `ReportDefinition`, `Filter`, `ReportLoader`, `ModuleGenerator`
  - Support for post-SQL filtering with operators (eq, ne, lt, lte, gt, gte)
  - Title interpolation with variable substitution using `${variable}` syntax
  - Enrichment hooks pattern for data transformation
  - Problem explanations configuration in YAML (field → explanation key mapping)
- **Filter UI** on report pages for manual parameter input:
  - Collapsible filter section with form inputs for each parameter
  - Support for threshold overrides (limit, min_duration_seconds, etc.)
  - Real-time report refresh with custom filter values
  - Horizontal layout with descriptions and inputs side-by-side
  - Dark theme styling for filter inputs and labels

### Changed

- Report definitions now use declarative YAML files instead of repetitive Ruby methods (~800 lines of code eliminated)
- Modules now use metaprogramming to dynamically generate methods from YAML at load time
- Dashboard category cards width increased from 280px to 350px for better readability
- Documentation and filter sections positioned side-by-side in responsive grid layout
- Filter parameters section positioned below documentation and collapsed by default
- Reduced vertical spacing between sections for more compact layout
- Problem field to explanation key mapping moved from hardcoded JavaScript to server-driven YAML configuration

### Fixed

- CSS Grid `align-items: stretch` causing synchronized expansion of documentation and filter blocks
- Visual "chin" appearing on closed filter details block due to default margins
- TypeError when report has no limit parameter default value
- Excessive margins between report sections

## [0.3.0] - 2026-01-28

### Added

- **Live Monitoring Panel** on the main dashboard with real-time metrics:
  - Connections (active/idle/total, % of max_connections)
  - TPS (transactions per second, calculated from pg_stat_database)
  - Cache Hit Ratio (heap blocks from cache)
  - Long Running Queries (count of queries > 60s)
  - Blocked Processes (waiting for locks)
- SVG sparkline charts showing 2.5 minutes of history (30 data points)
- Color-coded status indicators (green/yellow/red) based on thresholds
- Pause/resume button for live monitoring (state saved to localStorage)
- Auto-refresh every 5 seconds
- Responsive grid layout for metric cards
- New `/live_metrics` API endpoint

### Changed

- Dashboard now shows live monitoring panel above the categories grid

## [0.2.3] - 2026-01-28

### Added

- Query Analyzer modal with parameter input fields for `$1`, `$2`, etc. placeholders
- Execute Query button to run queries and view results (alongside EXPLAIN ANALYZE)
- Parameter syntax highlighting in Query Analyzer (rose color for `$1`, `$2`, etc.)

### Changed

- Split `show.html.erb` into partials for better maintainability:
  - `_show_styles.html.erb` - CSS styles
  - `_show_scripts.html.erb` - JavaScript
  - `_show_modals.html.erb` - Modal dialogs
- EXPLAIN ANALYZE button now only shown for SELECT queries
- Query encoding uses base64 to handle special characters (newlines, quotes)

### Fixed

- EXPLAIN ANALYZE button not working for queries with special characters
- Security: Only SELECT queries allowed for EXPLAIN ANALYZE, SELECT/SHOW for Execute Query

## [0.2.2] - 2026-01-28

### Added

- `fake_source_data` configuration option - enable via `PG_REPORTS_FAKE_SOURCE_DATA=true` env variable or in initializer
- Support for short controller#action format in source links (e.g., `posts#index` → `app/controllers/posts_controller.rb`)

### Changed

- Fake source data moved to separate partial file for cleaner code organization
- IDE link click handling improved with event delegation in capture phase

### Fixed

- Source badge clicks now work correctly without triggering row expansion
- Fallback fonts now use proper sans-serif system font stack when `load_external_fonts` is disabled

## [0.2.1] - 2026-01-28

### Added

- Cursor (WSL) IDE support

### Fixed

- Removed test data from production code
- Copy Query button now works correctly with special characters

## [0.2.0] - 2026-01-28

### Added

- Sortable table columns - click on column header to sort ascending/descending
- Top scrollbar for wide tables (synchronized with bottom scroll)
- Report descriptions in dashboard cards on the main page
- IDE integration for source code links:
  - VS Code (WSL) - for Windows Subsystem for Linux
  - VS Code - direct path for native Linux
  - RubyMine
  - IntelliJ IDEA
  - Cursor (WSL) - for Windows Subsystem for Linux
  - Cursor
- IDE settings modal to choose default IDE (skip menu and open directly)
- Save records for comparison - save query results to compare before/after optimizations
- EXPLAIN ANALYZE for queries - run EXPLAIN ANALYZE directly from the dashboard
- Migration generator for unused/broken indexes - generate and create migration files

### Changed

- Reduced spacing between report description and results table
- Dropdown menus now use fixed positioning to prevent clipping by table rows

## [0.1.0] - 2026-01-17

### Added

- Initial release
- Query analysis module (slow, heavy, expensive queries)
- Index analysis module (unused, duplicate, invalid, missing indexes)
- Table analysis module (sizes, bloat, vacuum status)
- Connection analysis module (active connections, locks, blocking queries)
- System module (database sizes, settings, extensions)
- Web dashboard with beautiful dark theme
- Expandable table rows for full query text
- Download reports in TXT, CSV, JSON formats
- Telegram integration for sending reports
- pg_stat_statements management (enable/status check)
