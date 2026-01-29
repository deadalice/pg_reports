-- Unique indexes: all unique indexes in the database
-- Used for validation consistency analysis

SELECT
  n.nspname AS schema_name,
  t.relname AS table_name,
  i.relname AS index_name,
  array_agg(a.attname ORDER BY array_position(ix.indkey, a.attnum)) AS column_names,
  pg_get_indexdef(i.oid) AS index_definition,
  CASE
    WHEN ix.indisprimary THEN 'primary_key'
    WHEN ix.indisunique THEN 'unique'
    ELSE 'regular'
  END AS index_type
FROM
  pg_index ix
  JOIN pg_class i ON i.oid = ix.indexrelid
  JOIN pg_class t ON t.oid = ix.indrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
WHERE
  n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
  AND (ix.indisunique = true OR ix.indisprimary = true)
  AND t.relkind = 'r'
GROUP BY
  n.nspname,
  t.relname,
  i.relname,
  i.oid,
  ix.indisprimary,
  ix.indisunique
ORDER BY
  n.nspname,
  t.relname,
  i.relname;
