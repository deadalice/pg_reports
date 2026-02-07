-- Connection Pool Saturation Analysis
-- Provides overall pool health metrics with warnings

WITH settings AS (
  SELECT
    (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') AS max_conn,
    (SELECT setting::int FROM pg_settings WHERE name = 'superuser_reserved_connections') AS reserved_conn
),
current_state AS (
  SELECT
    COUNT(*) AS total_connections,
    COUNT(*) FILTER (WHERE state = 'active') AS active_conn,
    COUNT(*) FILTER (WHERE state = 'idle') AS idle_conn,
    COUNT(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_txn,
    COUNT(*) FILTER (WHERE state = 'idle in transaction (aborted)') AS idle_in_txn_aborted,
    COUNT(*) FILTER (WHERE wait_event IS NOT NULL) AS waiting_conn
  FROM pg_stat_activity
  WHERE pid != pg_backend_pid()
),
metrics AS (
  SELECT
    'Total Connections' AS metric,
    cs.total_connections AS current_value,
    s.max_conn - s.reserved_conn AS max_value,
    ROUND((cs.total_connections::numeric / (s.max_conn - s.reserved_conn)::numeric) * 100, 2) AS utilization_pct
  FROM current_state cs, settings s

  UNION ALL

  SELECT
    'Active Connections',
    cs.active_conn,
    s.max_conn - s.reserved_conn,
    ROUND((cs.active_conn::numeric / (s.max_conn - s.reserved_conn)::numeric) * 100, 2)
  FROM current_state cs, settings s

  UNION ALL

  SELECT
    'Idle Connections',
    cs.idle_conn,
    s.max_conn - s.reserved_conn,
    ROUND((cs.idle_conn::numeric / (s.max_conn - s.reserved_conn)::numeric) * 100, 2)
  FROM current_state cs, settings s

  UNION ALL

  SELECT
    'Idle in Transaction',
    cs.idle_in_txn,
    s.max_conn / 4, -- Should be max 25% of pool
    ROUND((cs.idle_in_txn::numeric / (s.max_conn / 4)::numeric) * 100, 2)
  FROM current_state cs, settings s

  UNION ALL

  SELECT
    'Waiting Connections',
    cs.waiting_conn,
    s.max_conn / 10, -- Should be max 10% of pool
    ROUND((cs.waiting_conn::numeric / GREATEST(s.max_conn / 10, 1)::numeric) * 100, 2)
  FROM current_state cs, settings s
)
SELECT
  metric,
  current_value,
  max_value,
  utilization_pct,
  CASE
    WHEN utilization_pct >= 85 THEN '🔴 Critical'
    WHEN utilization_pct >= 70 THEN '🟡 Warning'
    WHEN utilization_pct >= 50 THEN '🟡 Elevated'
    ELSE '🟢 Normal'
  END AS status,
  CASE
    WHEN metric = 'Total Connections' AND utilization_pct >= 85 THEN
      'CRITICAL: Pool near exhaustion. Scale up max_connections or implement connection pooling immediately.'
    WHEN metric = 'Total Connections' AND utilization_pct >= 70 THEN
      'WARNING: High pool utilization. Consider increasing max_connections or adding connection pooler.'
    WHEN metric = 'Idle in Transaction' AND utilization_pct >= 70 THEN
      'WARNING: Too many idle in transaction connections. Review application transaction handling and set idle_in_transaction_session_timeout.'
    WHEN metric = 'Waiting Connections' AND utilization_pct >= 70 THEN
      'WARNING: Many connections waiting. Check for lock contention and long-running queries.'
    WHEN metric = 'Active Connections' AND utilization_pct >= 85 THEN
      'High active connection count. Monitor query performance and consider read replicas.'
    ELSE
      'Pool is healthy.'
  END AS recommendation
FROM metrics
ORDER BY utilization_pct DESC;
