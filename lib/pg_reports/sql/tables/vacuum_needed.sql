-- Tables needing vacuum
-- High dead row count or long time since last vacuum

SELECT
  schemaname AS schema,
  relname AS table_name,
  n_live_tup,
  n_dead_tup,
  CASE
    WHEN n_live_tup > 0 THEN
      ROUND((n_dead_tup * 100.0 / n_live_tup)::numeric, 2)
    ELSE 0
  END AS dead_ratio_percent,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  vacuum_count,
  autovacuum_count,
  pg_size_pretty(pg_table_size(relid)) AS table_size
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n_dead_tup DESC;
