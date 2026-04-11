-- Queries that spill to disk via temporary files
-- High temp file usage indicates insufficient work_mem for these queries

SELECT
  queryid,
  LEFT(query, :max_query_length) AS query,
  calls,
  ROUND(temp_blks_written::numeric * 8 / 1024, 2) AS temp_mb_written,
  ROUND(temp_blks_read::numeric * 8 / 1024, 2) AS temp_mb_read,
  ROUND((total_exec_time / 1000)::numeric, 2) AS total_time_sec,
  ROUND((mean_exec_time)::numeric, 2) AS mean_time_ms,
  rows
FROM pg_stat_statements
WHERE temp_blks_written > 0
  AND dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
ORDER BY temp_blks_written DESC;
