-- Queries potentially missing indexes
-- Identifies queries with patterns suggesting sequential scans
-- Requires pg_stat_statements extension

SELECT
  query,
  calls,
  ROUND((total_exec_time)::numeric, 2) AS total_time_ms,
  ROUND((mean_exec_time)::numeric, 2) AS mean_time_ms,
  rows,
  -- Heuristic: high rows examined per call may indicate missing index
  ROUND((rows / NULLIF(calls, 0))::numeric, 0) AS rows_per_call,
  -- High read/hit ratio suggests disk access (possible seq scan)
  ROUND((shared_blks_read * 100.0 / NULLIF(shared_blks_hit + shared_blks_read, 0))::numeric, 2) AS disk_read_ratio
FROM pg_stat_statements
WHERE calls > 10
  AND (rows / NULLIF(calls, 0)) > 100
  AND mean_exec_time > 10
  AND query NOT LIKE '%pg_stat_statements%'
  AND query NOT LIKE 'COMMIT%'
  AND query NOT LIKE 'BEGIN%'
  -- Focus on SELECT statements
  AND (query ILIKE 'SELECT%' OR query ILIKE '%WHERE%')
ORDER BY (rows / NULLIF(calls, 0)) * calls DESC
LIMIT 100;
