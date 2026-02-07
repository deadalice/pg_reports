-- Queries with low cache hit ratio
-- Requires pg_stat_statements extension

SELECT
  s.query,
  s.calls,
  ROUND((s.shared_blks_hit * 100.0 / NULLIF(s.shared_blks_hit + s.shared_blks_read, 0))::numeric, 2) AS cache_hit_ratio,
  s.shared_blks_hit,
  s.shared_blks_read,
  ROUND((s.total_exec_time)::numeric, 2) AS total_time_ms,
  ROUND((s.mean_exec_time)::numeric, 2) AS mean_time_ms
FROM pg_stat_statements s
JOIN pg_database d ON s.dbid = d.oid
WHERE s.calls > 10
  AND (s.shared_blks_hit + s.shared_blks_read) > 0
  AND s.query NOT LIKE '%pg_stat_statements%'
  AND s.query NOT LIKE 'COMMIT%'
  AND s.query NOT LIKE 'BEGIN%'
  AND d.datname = current_database()
ORDER BY (s.shared_blks_hit * 1.0 / NULLIF(s.shared_blks_hit + s.shared_blks_read, 0)) ASC
LIMIT 100;
