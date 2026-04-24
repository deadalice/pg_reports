-- Columns that have only ever held a single value (likely never updated since creation)
-- Uses pg_stats.n_distinct = 1 as a proxy for "no UPDATE has ever changed this field".
-- Strong indicator the application code no longer references the column but it was never dropped.

SELECT
  s.schemaname AS schema,
  s.tablename AS table_name,
  s.attname AS column_name,
  format_type(a.atttypid, a.atttypmod) AS data_type,
  CASE
    WHEN s.most_common_vals IS NOT NULL
      THEN substring((s.most_common_vals::text) FROM 1 FOR 80)
    ELSE NULL
  END AS sole_value,
  pg_get_expr(ad.adbin, ad.adrelid) AS column_default,
  ROUND((s.null_frac * 100)::numeric, 2) AS null_pct,
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
  AND s.n_distinct = 1
  AND s.null_frac < 0.999
  AND c.reltuples > 1000
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    WHERE i.indrelid = c.oid
      AND a.attnum = ANY(i.indkey)
      AND (i.indisprimary OR i.indisunique)
  )
ORDER BY c.reltuples DESC;
