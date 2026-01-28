-- Live monitoring metrics
-- Single optimized query for dashboard live metrics

WITH connection_stats AS (
  SELECT
    COUNT(*) FILTER (WHERE state = 'active' AND pid != pg_backend_pid()) AS active_connections,
    COUNT(*) FILTER (WHERE state = 'idle') AS idle_connections,
    COUNT(*) FILTER (WHERE pid != pg_backend_pid()) AS total_connections,
    (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS max_connections
  FROM pg_stat_activity
  WHERE datname = current_database()
),
tps_stats AS (
  SELECT
    xact_commit + xact_rollback AS total_transactions,
    xact_commit,
    xact_rollback
  FROM pg_stat_database
  WHERE datname = current_database()
),
cache_stats AS (
  SELECT
    CASE
      WHEN blks_hit + blks_read > 0 THEN
        ROUND((blks_hit * 100.0 / (blks_hit + blks_read))::numeric, 2)
      ELSE 100.0
    END AS heap_hit_ratio
  FROM pg_stat_database
  WHERE datname = current_database()
),
long_running AS (
  SELECT COUNT(*) AS count
  FROM pg_stat_activity
  WHERE datname = current_database()
    AND pid != pg_backend_pid()
    AND state = 'active'
    AND query_start IS NOT NULL
    AND EXTRACT(EPOCH FROM (NOW() - query_start)) > :long_query_threshold
),
blocked AS (
  SELECT COUNT(*) AS count
  FROM pg_locks
  WHERE NOT granted
)
SELECT
  cs.active_connections,
  cs.idle_connections,
  cs.total_connections,
  cs.max_connections,
  ROUND((cs.total_connections * 100.0 / NULLIF(cs.max_connections, 0))::numeric, 1) AS connections_pct,
  ts.total_transactions,
  ts.xact_commit,
  ts.xact_rollback,
  ca.heap_hit_ratio,
  lr.count AS long_running_count,
  bl.count AS blocked_count,
  EXTRACT(EPOCH FROM NOW()) AS timestamp_epoch
FROM connection_stats cs
CROSS JOIN tps_stats ts
CROSS JOIN cache_stats ca
CROSS JOIN long_running lr
CROSS JOIN blocked bl;
