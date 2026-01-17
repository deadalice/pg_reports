-- Table cache hit ratios
-- Low cache hit ratio may indicate need for more memory or index optimization

SELECT
  schemaname AS schema,
  relname AS table_name,
  heap_blks_read,
  heap_blks_hit,
  CASE
    WHEN heap_blks_hit + heap_blks_read > 0 THEN
      ROUND((heap_blks_hit * 100.0 / (heap_blks_hit + heap_blks_read))::numeric, 2)
    ELSE 100
  END AS cache_hit_ratio,
  idx_blks_read,
  idx_blks_hit,
  CASE
    WHEN idx_blks_hit + idx_blks_read > 0 THEN
      ROUND((idx_blks_hit * 100.0 / (idx_blks_hit + idx_blks_read))::numeric, 2)
    ELSE 100
  END AS idx_cache_hit_ratio
FROM pg_statio_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND (heap_blks_hit + heap_blks_read) > 0
ORDER BY cache_hit_ratio ASC;
