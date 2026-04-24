-- Tables with disproportionately high write activity
-- updates_per_row = n_tup_upd / n_live_tup -- same rows being updated repeatedly
-- hot_update_pct  = n_tup_hot_upd / n_tup_upd -- low value means indexed columns are being updated (expensive)

SELECT
  schemaname AS schema,
  relname AS table_name,
  n_live_tup AS live_rows,
  n_tup_upd AS updates,
  n_tup_hot_upd AS hot_updates,
  CASE WHEN n_tup_upd > 0
    THEN ROUND((n_tup_hot_upd::numeric / n_tup_upd) * 100, 2)
    ELSE 0
  END AS hot_update_pct,
  CASE WHEN n_live_tup > 0
    THEN ROUND(n_tup_upd::numeric / n_live_tup, 2)
    ELSE 0
  END AS updates_per_row,
  n_tup_ins AS inserts,
  n_tup_del AS deletes,
  n_dead_tup AS dead_rows
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND n_tup_upd > 1000
  AND n_live_tup > 100
ORDER BY (n_tup_upd::numeric / GREATEST(n_live_tup, 1)) DESC;
