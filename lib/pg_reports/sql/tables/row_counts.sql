-- Table row counts
-- Estimated row counts from statistics

SELECT
  schemaname AS schema,
  relname AS table_name,
  n_live_tup AS row_count,
  n_dead_tup AS dead_rows,
  pg_size_pretty(pg_table_size(relid)) AS table_size,
  ROUND(pg_table_size(relid) / 1024.0 / 1024.0, 2) AS table_size_mb,
  CASE
    WHEN n_live_tup > 0 THEN
      ROUND((pg_table_size(relid) / n_live_tup)::numeric, 0)
    ELSE 0
  END AS bytes_per_row
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n_live_tup DESC;
