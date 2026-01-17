-- Database activity overview
-- Summary metrics for current database activity

WITH stats AS (
  SELECT
    (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()) AS total_connections,
    (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND state = 'active') AS active_queries,
    (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND state = 'idle') AS idle_connections,
    (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND state = 'idle in transaction') AS idle_in_transaction,
    (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND wait_event IS NOT NULL) AS waiting_connections,
    (SELECT count(*) FROM pg_locks WHERE NOT granted) AS blocked_queries,
    (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS max_connections,
    (SELECT ROUND(pg_database_size(current_database()) / 1024.0 / 1024.0, 2)) AS database_size_mb
)
SELECT 'Total Connections' AS metric, total_connections::text AS value FROM stats
UNION ALL
SELECT 'Active Queries', active_queries::text FROM stats
UNION ALL
SELECT 'Idle Connections', idle_connections::text FROM stats
UNION ALL
SELECT 'Idle in Transaction', idle_in_transaction::text FROM stats
UNION ALL
SELECT 'Waiting Connections', waiting_connections::text FROM stats
UNION ALL
SELECT 'Blocked Queries', blocked_queries::text FROM stats
UNION ALL
SELECT 'Max Connections', max_connections::text FROM stats
UNION ALL
SELECT 'Database Size (MB)', database_size_mb::text FROM stats;
