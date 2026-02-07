-- List of all databases in the cluster
SELECT
  datname AS database,
  pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
WHERE datistemplate = false
  AND datallowconn = true
ORDER BY datname;
