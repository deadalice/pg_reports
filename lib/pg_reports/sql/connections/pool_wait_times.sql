-- Connection Pool Wait Time Analysis
-- Shows queries currently waiting for resources

SELECT
  pid,
  datname AS database,
  usename AS username,
  wait_event_type,
  wait_event,
  state,
  ROUND(EXTRACT(EPOCH FROM (NOW() - state_change))::numeric, 2) AS wait_duration_seconds,
  state_change AS query_start,
  LEFT(query, 500) AS query
FROM pg_stat_activity
WHERE wait_event IS NOT NULL
  AND pid != pg_backend_pid()
  AND datname IS NOT NULL
  AND state != 'idle'
ORDER BY wait_duration_seconds DESC;
