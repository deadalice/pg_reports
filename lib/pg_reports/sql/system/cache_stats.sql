-- Database cache statistics
-- Shows cache hit ratios for each database

SELECT
  datname AS database,
  ROUND(
    CASE
      WHEN blks_hit + blks_read > 0 THEN
        (blks_hit * 100.0 / (blks_hit + blks_read))
      ELSE 100
    END::numeric,
    2
  ) AS heap_hit_ratio,
  blks_hit,
  blks_read
FROM pg_stat_database
WHERE datname NOT LIKE 'template%'
  AND datname IS NOT NULL
ORDER BY datname;
