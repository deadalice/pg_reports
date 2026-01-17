-- Duplicate indexes: indexes that may be redundant
-- One index is a prefix of another on the same table

WITH index_cols AS (
  SELECT
    n.nspname AS schema,
    t.relname AS table_name,
    i.relname AS index_name,
    a.amname AS index_type,
    ARRAY_AGG(attr.attname ORDER BY array_position(ix.indkey, attr.attnum)) AS columns,
    pg_relation_size(i.oid) AS index_size
  FROM pg_index ix
  JOIN pg_class t ON t.oid = ix.indrelid
  JOIN pg_class i ON i.oid = ix.indexrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  JOIN pg_am a ON a.oid = i.relam
  JOIN pg_attribute attr ON attr.attrelid = t.oid AND attr.attnum = ANY(ix.indkey)
  WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  GROUP BY n.nspname, t.relname, i.relname, a.amname, i.oid
)
SELECT
  a.table_name,
  a.index_name,
  a.columns AS index_columns,
  b.index_name AS duplicate_of,
  b.columns AS duplicate_columns,
  pg_size_pretty(a.index_size) AS index_size,
  ROUND(a.index_size / 1024.0 / 1024.0, 2) AS index_size_mb
FROM index_cols a
JOIN index_cols b ON
  a.schema = b.schema AND
  a.table_name = b.table_name AND
  a.index_name != b.index_name AND
  a.index_type = b.index_type AND
  -- a's columns are a prefix of b's columns
  a.columns = b.columns[1:array_length(a.columns, 1)]
WHERE array_length(a.columns, 1) < array_length(b.columns, 1)
ORDER BY a.index_size DESC;
