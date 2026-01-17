-- Tables potentially missing indexes
-- High sequential scans with low or no index usage

SELECT
  schemaname AS schema,
  relname AS table_name,
  seq_scan,
  seq_tup_read,
  idx_scan,
  COALESCE(idx_scan, 0) AS idx_scan_count,
  CASE
    WHEN seq_scan > 0 THEN ROUND((seq_tup_read / seq_scan)::numeric, 0)
    ELSE 0
  END AS avg_seq_tup_read,
  pg_size_pretty(pg_relation_size(relid)) AS table_size,
  ROUND(pg_relation_size(relid) / 1024.0 / 1024.0, 2) AS table_size_mb,
  n_live_tup AS estimated_rows
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND seq_scan > 50
  AND pg_relation_size(relid) > 10 * 1024 * 1024  -- Tables > 10MB
  AND (
    idx_scan IS NULL
    OR idx_scan = 0
    OR (seq_scan::float / NULLIF(idx_scan, 0)) > 10
  )
ORDER BY seq_tup_read DESC NULLS LAST;
