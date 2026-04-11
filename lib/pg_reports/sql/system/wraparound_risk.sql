-- Transaction ID wraparound risk
-- When age(datfrozenxid) approaches 2 billion, PostgreSQL will shut down
-- to prevent data corruption. Monitor this to trigger preventive VACUUM FREEZE.

SELECT
  d.datname AS database_name,
  age(d.datfrozenxid) AS xid_age,
  ROUND(age(d.datfrozenxid)::numeric / 2147483647 * 100, 2) AS pct_towards_wraparound,
  2147483647 - age(d.datfrozenxid) AS remaining_xids,
  current_setting('autovacuum_freeze_max_age')::bigint AS freeze_max_age,
  CASE
    WHEN age(d.datfrozenxid) > current_setting('autovacuum_freeze_max_age')::bigint
    THEN 'CRITICAL - exceeds freeze_max_age'
    WHEN age(d.datfrozenxid) > current_setting('autovacuum_freeze_max_age')::bigint * 0.75
    THEN 'WARNING - approaching freeze_max_age'
    ELSE 'OK'
  END AS status,
  pg_size_pretty(pg_database_size(d.datname)) AS database_size
FROM pg_database d
WHERE d.datallowconn = true
ORDER BY age(d.datfrozenxid) DESC;
