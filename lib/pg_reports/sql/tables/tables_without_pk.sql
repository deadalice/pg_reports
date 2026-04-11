-- Tables without primary keys
-- Missing PKs break logical replication and make row identification unreliable

SELECT
  n.nspname AS schema,
  c.relname AS table_name,
  c.reltuples::bigint AS estimated_rows,
  pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
  ROUND(pg_relation_size(c.oid) / 1024.0 / 1024.0, 2) AS table_size_mb
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND NOT EXISTS (
    SELECT 1
    FROM pg_index i
    WHERE i.indrelid = c.oid
      AND i.indisprimary
  )
ORDER BY pg_relation_size(c.oid) DESC;
