-- Long running queries
-- Queries that have been running for extended period

SELECT
  pid,
  datname AS database,
  usename AS username,
  application_name AS application,
  client_addr,
  state,
  EXTRACT(EPOCH FROM (NOW() - query_start)) AS duration_seconds,
  query_start,
  wait_event_type,
  wait_event,
  LEFT(query, 500) AS query
FROM pg_stat_activity
WHERE datname IS NOT NULL
  AND pid != pg_backend_pid()
  AND state = 'active'
  AND query_start IS NOT NULL
ORDER BY duration_seconds DESC;
