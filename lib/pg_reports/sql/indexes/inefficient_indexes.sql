-- Inefficient index scans: indexes that are used but read far more entries than they fetch
-- A high idx_tup_read / idx_tup_fetch ratio indicates the index column order
-- does not match query predicates, forcing PostgreSQL to scan large index ranges
-- Reference: https://www.datadoghq.com/blog/detect-inefficient-index-scans-with-dbm/

SELECT
  schemaname AS schema,
  relname AS table_name,
  indexrelname AS index_name,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch,
  ROUND((idx_tup_read::numeric / NULLIF(idx_tup_fetch, 0)), 1) AS read_to_fetch_ratio,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  ROUND(pg_relation_size(indexrelid) / 1024.0 / 1024.0, 2) AS index_size_mb,
  pg_get_indexdef(indexrelid) AS index_definition
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND idx_scan > 0
  AND idx_tup_fetch > 0
  AND (idx_tup_read::numeric / NULLIF(idx_tup_fetch, 0)) > 10
ORDER BY (idx_tup_read::numeric / NULLIF(idx_tup_fetch, 0)) DESC;
