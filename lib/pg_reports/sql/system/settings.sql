-- Important PostgreSQL settings
-- Shows key configuration parameters

SELECT
  name,
  setting,
  unit,
  category,
  short_desc AS description
FROM pg_settings
WHERE name IN (
  'shared_buffers',
  'effective_cache_size',
  'work_mem',
  'maintenance_work_mem',
  'max_connections',
  'max_parallel_workers',
  'max_parallel_workers_per_gather',
  'random_page_cost',
  'seq_page_cost',
  'effective_io_concurrency',
  'wal_buffers',
  'checkpoint_completion_target',
  'default_statistics_target',
  'statement_timeout',
  'lock_timeout',
  'idle_in_transaction_session_timeout',
  'log_min_duration_statement',
  'autovacuum',
  'autovacuum_vacuum_scale_factor',
  'autovacuum_analyze_scale_factor'
)
ORDER BY category, name;
