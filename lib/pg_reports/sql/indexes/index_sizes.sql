-- Index sizes
-- Shows all indexes sorted by size

SELECT
  schemaname AS schema,
  relname AS table_name,
  indexrelname AS index_name,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  ROUND(pg_relation_size(indexrelid) / 1024.0 / 1024.0, 2) AS index_size_mb,
  idx_scan,
  idx_tup_read
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(indexrelid) DESC;
