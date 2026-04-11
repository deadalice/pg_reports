-- Foreign keys without indexes on the referencing (child) table
-- Missing indexes cause sequential scans on DELETE/UPDATE of parent rows

SELECT
  c.conname AS constraint_name,
  c.conrelid::regclass::text AS child_table,
  a.attname AS child_column,
  c.confrelid::regclass::text AS parent_table,
  pa.attname AS parent_column,
  pg_size_pretty(pg_relation_size(c.conrelid)) AS child_table_size,
  ROUND(pg_relation_size(c.conrelid) / 1024.0 / 1024.0, 2) AS child_table_size_mb
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
JOIN pg_attribute pa ON pa.attrelid = c.confrelid AND pa.attnum = ANY(c.confkey)
WHERE c.contype = 'f'
  AND NOT EXISTS (
    SELECT 1
    FROM pg_index i
    WHERE i.indrelid = c.conrelid
      AND a.attnum = ANY(i.indkey)
      AND i.indkey[0] = a.attnum
  )
ORDER BY pg_relation_size(c.conrelid) DESC;
