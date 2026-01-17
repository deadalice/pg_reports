-- Invalid indexes: indexes that are not valid
-- These may have failed during concurrent creation

SELECT
  n.nspname AS schema,
  t.relname AS table_name,
  i.relname AS index_name,
  pg_get_indexdef(i.oid) AS index_definition
FROM pg_index ix
JOIN pg_class t ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE NOT ix.indisvalid
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n.nspname, t.relname, i.relname;
