-- Bloated tables: tables with high dead tuple ratio
-- High bloat indicates need for VACUUM

SELECT
  schemaname AS schema,
  relname AS table_name,
  n_live_tup AS live_rows,
  n_dead_tup AS dead_rows,
  CASE
    WHEN n_live_tup + n_dead_tup > 0 THEN
      ROUND((n_dead_tup * 100.0 / (n_live_tup + n_dead_tup))::numeric, 2)
    ELSE 0
  END AS bloat_percent,
  pg_size_pretty(pg_table_size(relid)) AS table_size,
  ROUND(pg_table_size(relid) / 1024.0 / 1024.0, 2) AS table_size_mb,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND n_live_tup + n_dead_tup > 1000
ORDER BY n_dead_tup DESC;
