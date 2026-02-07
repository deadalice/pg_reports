-- All query statistics ordered by total time
-- Requires pg_stat_statements extension

SELECT
  s.query,
  s.calls,
  ROUND((s.total_exec_time)::numeric, 2) AS total_time_ms,
  ROUND((s.mean_exec_time)::numeric, 2) AS mean_time_ms,
  ROUND((s.min_exec_time)::numeric, 2) AS min_time_ms,
  ROUND((s.max_exec_time)::numeric, 2) AS max_time_ms,
  ROUND((s.stddev_exec_time)::numeric, 2) AS stddev_time_ms,
  s.rows,
  s.shared_blks_hit,
  s.shared_blks_read,
  ROUND((s.shared_blks_hit * 100.0 / NULLIF(s.shared_blks_hit + s.shared_blks_read, 0))::numeric, 2) AS cache_hit_ratio
FROM pg_stat_statements s
JOIN pg_database d ON s.dbid = d.oid
WHERE s.calls > 0
  AND s.query NOT LIKE '%pg_stat_statements%'
  AND d.datname = current_database()
ORDER BY s.total_exec_time DESC
LIMIT 200;
