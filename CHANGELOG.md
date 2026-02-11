# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
