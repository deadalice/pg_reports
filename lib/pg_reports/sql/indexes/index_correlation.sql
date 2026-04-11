-- Index correlation: how well physical row order matches index order
-- Low correlation on frequently range-scanned columns means excessive random I/O

SELECT
  s.schemaname AS schema,
  s.tablename AS table_name,
  s.attname AS column_name,
  i.indexrelname AS index_name,
  ROUND(s.correlation::numeric, 4) AS correlation,
  ABS(s.correlation) AS abs_correlation,
  s.n_distinct,
  pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
  ROUND(pg_relation_size(c.oid) / 1024.0 / 1024.0, 2) AS table_size_mb,
  si.idx_scan
FROM pg_stats s
JOIN pg_class c ON c.relname = s.tablename
  AND c.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = s.schemaname)
JOIN pg_index idx ON idx.indrelid = c.oid
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = s.attname
  AND a.attnum = idx.indkey[0]
JOIN pg_stat_user_indexes i ON i.indexrelid = idx.indexrelid
JOIN pg_stat_user_indexes si ON si.indexrelid = idx.indexrelid
WHERE s.schemaname NOT IN ('pg_catalog', 'information_schema')
  AND ABS(s.correlation) < 0.5
  AND pg_relation_size(c.oid) > 10 * 1024 * 1024
  AND si.idx_scan > 100
ORDER BY ABS(s.correlation) ASC, pg_relation_size(c.oid) DESC;
