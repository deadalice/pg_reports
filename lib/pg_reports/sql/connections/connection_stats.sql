-- Connection statistics by state
-- Summary of connections grouped by database and state

SELECT
  datname AS database,
  state,
  COUNT(*) AS count,
  COUNT(*) FILTER (WHERE wait_event IS NOT NULL) AS waiting_count
FROM pg_stat_activity
WHERE datname IS NOT NULL
  AND pid != pg_backend_pid()
GROUP BY datname, state
ORDER BY datname, count DESC;
