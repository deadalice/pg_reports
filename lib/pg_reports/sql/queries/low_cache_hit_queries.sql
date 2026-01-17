-- Queries with low cache hit ratio
-- Requires pg_stat_statements extension

SELECT
  query,
  calls,
  ROUND((shared_blks_hit * 100.0 / NULLIF(shared_blks_hit + shared_blks_read, 0))::numeric, 2) AS cache_hit_ratio,
  shared_blks_hit,
  shared_blks_read,
  ROUND((total_exec_time)::numeric, 2) AS total_time_ms,
  ROUND((mean_exec_time)::numeric, 2) AS mean_time_ms
FROM pg_stat_statements
WHERE calls > 10
  AND (shared_blks_hit + shared_blks_read) > 0
  AND query NOT LIKE '%pg_stat_statements%'
  AND query NOT LIKE 'COMMIT%'
  AND query NOT LIKE 'BEGIN%'
ORDER BY (shared_blks_hit * 1.0 / NULLIF(shared_blks_hit + shared_blks_read, 0)) ASC
LIMIT 100;
