-- Table sizes including indexes
-- Shows disk usage for each table

SELECT
  schemaname AS schema,
  relname AS table_name,
  pg_size_pretty(pg_table_size(relid)) AS table_size,
  ROUND(pg_table_size(relid) / 1024.0 / 1024.0, 2) AS table_size_mb,
  pg_size_pretty(pg_indexes_size(relid)) AS index_size,
  ROUND(pg_indexes_size(relid) / 1024.0 / 1024.0, 2) AS index_size_mb,
  pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
  ROUND(pg_total_relation_size(relid) / 1024.0 / 1024.0, 2) AS total_size_mb,
  n_live_tup AS row_count
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(relid) DESC;
