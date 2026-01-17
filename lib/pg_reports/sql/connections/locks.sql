-- Current locks
-- Shows all locks held in the database

SELECT
  l.pid,
  a.datname AS database,
  a.usename AS username,
  COALESCE(c.relname, l.relation::text) AS relation,
  l.locktype,
  l.mode,
  l.granted,
  NOT l.granted AS waiting,
  EXTRACT(EPOCH FROM (NOW() - a.query_start)) AS query_duration,
  LEFT(a.query, 300) AS query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
LEFT JOIN pg_class c ON l.relation = c.oid
WHERE a.datname IS NOT NULL
  AND l.pid != pg_backend_pid()
ORDER BY l.granted, l.pid;
