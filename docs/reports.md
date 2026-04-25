# Available Reports

All reports are available both via the dashboard (under their category) and as Ruby methods on `PgReports`. Methods accept keyword arguments matching the YAML-defined parameters (most accept `limit:`).

```ruby
PgReports.slow_queries(limit: 10).display
PgReports.unused_indexes.send_to_telegram
```

Reports marked **🆕** were added in 0.6.1.

## Queries

Requires `pg_stat_statements`. See [pg_stat_statements setup](../README.md#pg_stat_statements-setup).

| Method | Description |
|--------|-------------|
| `slow_queries` | Queries with high mean execution time |
| `heavy_queries` | Most frequently called queries |
| `expensive_queries` | Queries consuming most total time |
| `missing_index_queries` | Queries potentially missing indexes |
| `low_cache_hit_queries` | Queries with poor cache utilization |
| `temp_file_queries` | Queries spilling to disk via temporary files |
| `all_queries` | All query statistics |
| `reset_statistics!` | Reset pg_stat_statements data |

## Indexes

| Method | Description |
|--------|-------------|
| `unused_indexes` | Indexes rarely or never scanned |
| `duplicate_indexes` | Redundant indexes (one is a prefix of another) |
| `invalid_indexes` | Indexes that failed to build (`indisvalid = false`) |
| `missing_indexes` | Tables potentially missing indexes |
| `inefficient_indexes` | Indexes with high read-to-fetch ratio (misaligned column order) |
| `fk_without_indexes` | Foreign keys missing indexes on the child table |
| `index_correlation` | Low physical correlation causing random I/O on range scans |
| `index_usage` | Index scan statistics |
| `bloated_indexes` | Indexes with high bloat |
| `index_sizes` | Index disk usage |

## Tables

| Method | Description |
|--------|-------------|
| `table_sizes` | Table disk usage |
| `bloated_tables` | Tables with high dead tuple ratio |
| `vacuum_needed` | Tables needing vacuum |
| `row_counts` | Table row counts |
| `cache_hit_ratios` | Table cache statistics |
| `seq_scans` | Tables with high sequential scans |
| `tables_without_pk` | Tables missing primary keys |
| `recently_modified` | Tables with recent INSERT/UPDATE/DELETE activity |
| `update_hotspots` 🆕 | Same rows or indexed columns updated repeatedly |
| `unused_tables` 🆕 | Tables never queried since the last stats reset |

## Connections

| Method | Description |
|--------|-------------|
| `active_connections` | Current database connections |
| `connection_stats` | Connection statistics by state |
| `long_running_queries` | Queries running for extended period |
| `blocking_queries` | Queries blocking others |
| `locks` | Current database locks |
| `idle_connections` | Idle connections |
| `pool_usage` | Connection pool utilization |
| `pool_wait_times` | Resource wait time analysis |
| `pool_saturation` | Pool health warnings with recommendations |
| `connection_churn` | Connection lifecycle and churn rate analysis |
| `kill_connection(pid)` | Terminate a backend process |
| `cancel_query(pid)` | Cancel a running query |

## System

| Method | Description |
|--------|-------------|
| `database_sizes` | Size of all databases |
| `settings` | PostgreSQL configuration |
| `extensions` | Installed extensions |
| `activity_overview` | Current activity summary |
| `wraparound_risk` | Transaction ID wraparound proximity |
| `checkpoint_stats` | Checkpoint and bgwriter statistics (PG 12–18+) |
| `cache_stats` | Database cache statistics |
| `pg_stat_statements_available?` | Check if extension is ready |
| `enable_pg_stat_statements!` | Create the extension |

## Schema Analysis

These reports cross-reference database state with Rails models. They call `Rails.application.eager_load!`, so the first run on a large monolith may take a few seconds.

| Method | Description |
|--------|-------------|
| `missing_validations` | Unique indexes without corresponding model `uniqueness:` validations |
| `unused_columns` 🆕 | Columns that have only ever held a single value (likely never updated since creation) |
| `always_null_columns` 🆕 | Nullable columns where ~100% of rows are NULL |
| `polymorphic_without_index` 🆕 | Polymorphic `belongs_to` whose `(*_type, *_id)` pair has no composite index |
| `counter_cache_issues` 🆕 | `counter_cache:` declarations whose target column is missing on the parent table |
| `soft_delete_without_scope` 🆕 | `deleted_at` / `discarded_at` / `archived_at` columns without a model scope filtering them |
| `orphan_tables` 🆕 | DB tables with no corresponding Rails model (legacy / HABTM / out-of-band) |
