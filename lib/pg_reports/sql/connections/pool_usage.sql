-- Connection Pool Usage Statistics
-- Shows current pool utilization across databases

WITH connection_counts AS (
  SELECT
    COALESCE(datname, 'system') AS database,
    COUNT(*) AS total_connections,
    COUNT(*) FILTER (WHERE state = 'active') AS active_connections,
    COUNT(*) FILTER (WHERE state = 'idle') AS idle_connections,
    COUNT(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_transaction
  FROM pg_stat_activity
  WHERE pid != pg_backend_pid()
  GROUP BY datname
),
limits AS (
  SELECT setting::int AS max_connections
  FROM pg_settings
  WHERE name = 'max_connections'
)
SELECT
  cc.database,
  cc.total_connections,
  cc.active_connections,
  cc.idle_connections,
  cc.idle_in_transaction,
  l.max_connections,
  ROUND((cc.total_connections::numeric / l.max_connections::numeric) * 100, 2) AS utilization_pct,
  l.max_connections - cc.total_connections AS available_connections
FROM connection_counts cc
CROSS JOIN limits l
ORDER BY cc.total_connections DESC;
