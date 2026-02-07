-- Connection Churn Analysis
-- Identifies applications with excessive connection turnover

WITH connection_ages AS (
  SELECT
    datname AS database,
    COALESCE(application_name, 'unknown') AS application,
    EXTRACT(EPOCH FROM (NOW() - backend_start)) AS connection_age_seconds
  FROM pg_stat_activity
  WHERE pid != pg_backend_pid()
    AND datname IS NOT NULL
    AND backend_type = 'client backend'
),
connection_stats AS (
  SELECT
    database,
    application,
    COUNT(*) AS total_connections,
    ROUND(AVG(connection_age_seconds)::numeric, 2) AS avg_connection_age_seconds,
    ROUND(MIN(connection_age_seconds)::numeric, 2) AS min_connection_age_seconds,
    ROUND(MAX(connection_age_seconds)::numeric, 2) AS max_connection_age_seconds,
    COUNT(*) FILTER (WHERE connection_age_seconds < 10) AS short_lived_connections
  FROM connection_ages
  GROUP BY database, application
)
SELECT
  database,
  application,
  total_connections,
  avg_connection_age_seconds,
  min_connection_age_seconds,
  max_connection_age_seconds,
  short_lived_connections,
  ROUND((short_lived_connections::numeric / total_connections::numeric) * 100, 2) AS churn_rate_pct
FROM connection_stats
WHERE total_connections > 1  -- Filter out single connections
ORDER BY churn_rate_pct DESC, short_lived_connections DESC;
