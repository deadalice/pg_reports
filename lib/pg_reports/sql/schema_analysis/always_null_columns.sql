-- Columns where ~100% of rows are NULL
-- Strong indicator nothing in the application populates this column anymore.

SELECT
  s.schemaname AS schema,
  s.tablename AS table_name,
  s.attname AS column_name,
  format_type(a.atttypid, a.atttypmod) AS data_type,
  ROUND((s.null_frac * 100)::numeric, 2) AS null_pct,
  pg_get_expr(ad.adbin, ad.adrelid) AS column_default,
  a.attnotnull AS not_null_constraint,
  c.reltuples::bigint AS estimated_rows
FROM pg_stats s
JOIN pg_class c ON c.relname = s.tablename
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = s.schemaname
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = s.attname
LEFT JOIN pg_attrdef ad ON ad.adrelid = c.oid AND ad.adnum = a.attnum
WHERE s.schemaname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND c.relkind = 'r'
  AND a.attnum > 0
  AND NOT a.attisdropped
  AND a.attnotnull = false
  AND s.null_frac >= 0.999
  AND c.reltuples > 1000
ORDER BY c.reltuples DESC;
