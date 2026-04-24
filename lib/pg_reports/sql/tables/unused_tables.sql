-- Tables that have not been read at all since the last stats reset
-- Zero seq_scan AND zero idx_scan -- application code never queries them.
-- Candidates for archival, deletion, or extraction to a separate database.

SELECT
  t.schemaname AS schema,
  t.relname AS table_name,
  t.n_live_tup AS live_rows,
  pg_size_pretty(pg_total_relation_size(t.relid)) AS total_size,
  ROUND(pg_total_relation_size(t.relid) / 1024.0 / 1024.0, 2) AS total_size_mb,
  COALESCE(t.last_autoanalyze, t.last_analyze) AS last_analyzed,
  d.stats_reset AS db_stats_since
FROM pg_stat_user_tables t
LEFT JOIN pg_stat_database d ON d.datname = current_database()
WHERE t.schemaname NOT IN ('pg_catalog', 'information_schema')
  AND t.seq_scan = 0
  AND COALESCE(t.idx_scan, 0) = 0
  AND t.n_live_tup > 0
ORDER BY pg_total_relation_size(t.relid) DESC;
