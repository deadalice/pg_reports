# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

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
