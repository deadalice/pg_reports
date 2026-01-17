-- Slow queries: queries with high mean execution time
-- Requires pg_stat_statements extension

SELECT
  query,
  calls,
  ROUND((mean_exec_time)::numeric, 2) AS mean_time_ms,
  ROUND((total_exec_time)::numeric, 2) AS total_time_ms,
  ROUND((rows / NULLIF(calls, 0))::numeric, 2) AS rows_per_call,
  ROUND((shared_blks_hit * 100.0 / NULLIF(shared_blks_hit + shared_blks_read, 0))::numeric, 2) AS cache_hit_ratio
FROM pg_stat_statements
WHERE calls > 0
  AND query NOT LIKE '%pg_stat_statements%'
  AND query NOT LIKE 'COMMIT%'
  AND query NOT LIKE 'BEGIN%'
ORDER BY mean_exec_time DESC
LIMIT 100;
