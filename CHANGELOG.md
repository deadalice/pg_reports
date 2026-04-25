# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
