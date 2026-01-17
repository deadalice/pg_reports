-- Index usage statistics
-- Shows how often each index is scanned

SELECT
  schemaname AS schema,
  relname AS table_name,
  indexrelname AS index_name,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  ROUND(pg_relation_size(indexrelid) / 1024.0 / 1024.0, 2) AS index_size_mb,
  CASE
    WHEN idx_scan > 0 THEN ROUND((idx_tup_read / idx_scan)::numeric, 2)
    ELSE 0
  END AS avg_tuples_per_scan
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY idx_scan DESC;
