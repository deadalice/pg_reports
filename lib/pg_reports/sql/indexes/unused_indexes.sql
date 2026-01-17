-- Unused indexes: indexes that are rarely or never scanned
-- These indexes waste disk space and slow down writes

SELECT
  schemaname AS schema,
  relname AS table_name,
  indexrelname AS index_name,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  ROUND(pg_relation_size(indexrelid) / 1024.0 / 1024.0, 2) AS index_size_mb
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND idx_scan = 0
  AND indexrelname NOT LIKE '%_pkey'
  AND indexrelname NOT LIKE '%_unique%'
ORDER BY pg_relation_size(indexrelid) DESC;
