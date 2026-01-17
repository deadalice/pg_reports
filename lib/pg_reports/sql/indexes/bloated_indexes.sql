-- Bloated indexes: indexes with estimated bloat
-- Uses pgstattuple extension if available, otherwise estimates

WITH index_stats AS (
  SELECT
    schemaname AS schema,
    tablename AS table_name,
    indexname AS index_name,
    pg_relation_size(indexname::regclass) AS index_size,
    -- Estimate bloat using relation page count vs expected
    CASE
      WHEN pg_relation_size(indexname::regclass) > 0 THEN
        ROUND(
          (
            (pg_relation_size(indexname::regclass) -
             (SELECT reltuples * 8 FROM pg_class WHERE relname = indexname))
            * 100.0 / pg_relation_size(indexname::regclass)
          )::numeric,
          2
        )
      ELSE 0
    END AS estimated_bloat_percent
  FROM pg_indexes
  WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
)
SELECT
  schema,
  table_name,
  index_name,
  pg_size_pretty(index_size) AS index_size,
  ROUND(index_size / 1024.0 / 1024.0, 2) AS index_size_mb,
  GREATEST(estimated_bloat_percent, 0) AS bloat_percent,
  ROUND(GREATEST(estimated_bloat_percent, 0) * index_size / 100.0 / 1024.0 / 1024.0, 2) AS bloat_size_mb
FROM index_stats
WHERE index_size > 1024 * 1024  -- Only indexes > 1MB
ORDER BY index_size DESC;
