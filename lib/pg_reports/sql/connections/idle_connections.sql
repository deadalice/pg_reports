-- Idle connections
-- Shows connections that are idle

SELECT
  pid,
  datname AS database,
  usename AS username,
  application_name AS application,
  client_addr,
  state,
  EXTRACT(EPOCH FROM (NOW() - state_change)) AS idle_duration,
  state_change,
  query_start,
  LEFT(query, 200) AS last_query
FROM pg_stat_activity
WHERE datname IS NOT NULL
  AND pid != pg_backend_pid()
  AND state IN ('idle', 'idle in transaction', 'idle in transaction (aborted)')
ORDER BY idle_duration DESC;
