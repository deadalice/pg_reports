-- Sequential scan statistics
-- High sequential scans may indicate missing indexes

SELECT
  schemaname AS schema,
  relname AS table_name,
  seq_scan,
  seq_tup_read,
  CASE
    WHEN seq_scan > 0 THEN
      ROUND((seq_tup_read / seq_scan)::numeric, 0)
    ELSE 0
  END AS rows_per_seq_scan,
  idx_scan,
  idx_tup_fetch,
  CASE
    WHEN seq_scan + COALESCE(idx_scan, 0) > 0 THEN
      ROUND((seq_scan * 100.0 / (seq_scan + COALESCE(idx_scan, 0)))::numeric, 2)
    ELSE 0
  END AS seq_scan_ratio,
  pg_size_pretty(pg_table_size(relid)) AS table_size,
  n_live_tup AS row_count
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND seq_scan > 0
ORDER BY seq_tup_read DESC;
