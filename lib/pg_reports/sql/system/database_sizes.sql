-- Database sizes
-- Shows size of all databases

SELECT
  datname AS database,
  ROUND(pg_database_size(datname) / 1024.0 / 1024.0, 2) AS size_mb,
  pg_size_pretty(pg_database_size(datname)) AS size_pretty
FROM pg_database
WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;
