-- All query statistics ordered by total time
-- Requires pg_stat_statements extension

SELECT
  query,
  calls,
  ROUND((total_exec_time)::numeric, 2) AS total_time_ms,
  ROUND((mean_exec_time)::numeric, 2) AS mean_time_ms,
  ROUND((min_exec_time)::numeric, 2) AS min_time_ms,
  ROUND((max_exec_time)::numeric, 2) AS max_time_ms,
  ROUND((stddev_exec_time)::numeric, 2) AS stddev_time_ms,
  rows,
  shared_blks_hit,
  shared_blks_read,
  ROUND((shared_blks_hit * 100.0 / NULLIF(shared_blks_hit + shared_blks_read, 0))::numeric, 2) AS cache_hit_ratio
FROM pg_stat_statements
WHERE calls > 0
  AND query NOT LIKE '%pg_stat_statements%'
ORDER BY total_exec_time DESC
LIMIT 200;
