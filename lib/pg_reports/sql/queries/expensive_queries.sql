-- Expensive queries: queries consuming most total time
-- Requires pg_stat_statements extension

WITH total AS (
  SELECT SUM(total_exec_time) AS total_time
  FROM pg_stat_statements
  WHERE calls > 0
)
SELECT
  s.query,
  s.calls,
  ROUND((s.total_exec_time)::numeric, 2) AS total_time_ms,
  ROUND((s.total_exec_time * 100.0 / t.total_time)::numeric, 2) AS percent_of_total,
  ROUND((s.mean_exec_time)::numeric, 2) AS mean_time_ms,
  s.rows
FROM pg_stat_statements s, total t
WHERE s.calls > 0
  AND s.query NOT LIKE '%pg_stat_statements%'
  AND s.query NOT LIKE 'COMMIT%'
  AND s.query NOT LIKE 'BEGIN%'
ORDER BY s.total_exec_time DESC
LIMIT 100;
