-- Slow queries: queries with high mean execution time
-- Requires pg_stat_statements extension

SELECT
  s.query,
  s.calls,
  ROUND((s.mean_exec_time)::numeric, 2) AS mean_time_ms,
  ROUND((s.total_exec_time)::numeric, 2) AS total_time_ms,
  ROUND((s.rows / NULLIF(s.calls, 0))::numeric, 2) AS rows_per_call,
  ROUND((s.shared_blks_hit * 100.0 / NULLIF(s.shared_blks_hit + s.shared_blks_read, 0))::numeric, 2) AS cache_hit_ratio
FROM pg_stat_statements s
JOIN pg_database d ON s.dbid = d.oid
WHERE s.calls > 0
  AND s.query NOT LIKE '%pg_stat_statements%'
  AND s.query NOT LIKE 'COMMIT%'
  AND s.query NOT LIKE 'BEGIN%'
  AND d.datname = current_database()
ORDER BY s.mean_exec_time DESC
LIMIT 100;
