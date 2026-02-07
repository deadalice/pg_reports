-- Queries potentially missing indexes
-- Identifies queries with patterns suggesting sequential scans
-- Requires pg_stat_statements extension

SELECT
  s.query,
  s.calls,
  ROUND((s.total_exec_time)::numeric, 2) AS total_time_ms,
  ROUND((s.mean_exec_time)::numeric, 2) AS mean_time_ms,
  s.rows,
  -- Heuristic: high rows examined per call may indicate missing index
  ROUND((s.rows / NULLIF(s.calls, 0))::numeric, 0) AS rows_per_call,
  -- High read/hit ratio suggests disk access (possible seq scan)
  ROUND((s.shared_blks_read * 100.0 / NULLIF(s.shared_blks_hit + s.shared_blks_read, 0))::numeric, 2) AS disk_read_ratio
FROM pg_stat_statements s
JOIN pg_database d ON s.dbid = d.oid
WHERE s.calls > 10
  AND (s.rows / NULLIF(s.calls, 0)) > 100
  AND s.mean_exec_time > 10
  AND s.query NOT LIKE '%pg_stat_statements%'
  AND s.query NOT LIKE 'COMMIT%'
  AND s.query NOT LIKE 'BEGIN%'
  -- Focus on SELECT statements
  AND (s.query ILIKE 'SELECT%' OR s.query ILIKE '%WHERE%')
  AND d.datname = current_database()
ORDER BY (s.rows / NULLIF(s.calls, 0)) * s.calls DESC
LIMIT 100;
