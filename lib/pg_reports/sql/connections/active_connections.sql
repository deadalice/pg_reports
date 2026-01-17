-- Active connections
-- Shows all current database connections

SELECT
  pid,
  datname AS database,
  usename AS username,
  application_name AS application,
  client_addr,
  client_hostname,
  state,
  query_start,
  state_change,
  wait_event_type,
  wait_event,
  LEFT(query, 500) AS query
FROM pg_stat_activity
WHERE datname IS NOT NULL
  AND pid != pg_backend_pid()
ORDER BY query_start DESC NULLS LAST;
