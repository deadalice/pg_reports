-- Recently modified tables
-- Tables with recent insert/update/delete activity

SELECT
  schemaname AS schema,
  relname AS table_name,
  n_tup_ins AS inserts,
  n_tup_upd AS updates,
  n_tup_del AS deletes,
  n_tup_hot_upd AS hot_updates,
  n_live_tup AS live_rows,
  n_dead_tup AS dead_rows,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND (n_tup_ins + n_tup_upd + n_tup_del) > 0
ORDER BY (n_tup_ins + n_tup_upd + n_tup_del) DESC;
