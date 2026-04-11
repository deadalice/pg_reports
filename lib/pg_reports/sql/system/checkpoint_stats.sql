-- Checkpoint and background writer statistics (PostgreSQL 17+)
-- Uses pg_stat_checkpointer (introduced in PG 17) + pg_stat_bgwriter for bgwriter-only stats

SELECT
  pg_stat_get_checkpointer_num_timed() AS checkpoints_timed,
  pg_stat_get_checkpointer_num_requested() AS checkpoints_requested,
  ROUND(pg_stat_get_checkpointer_write_time()::numeric / 1000, 2) AS checkpoint_write_time_sec,
  ROUND(pg_stat_get_checkpointer_sync_time()::numeric / 1000, 2) AS checkpoint_sync_time_sec,
  pg_stat_get_checkpointer_buffers_written() AS buffers_checkpoint,
  pg_stat_get_bgwriter_buf_written_clean() AS buffers_clean,
  pg_stat_get_bgwriter_maxwritten_clean() AS bgwriter_stops,
  pg_stat_get_buf_alloc() AS buffers_alloc,
  CASE
    WHEN (pg_stat_get_checkpointer_num_timed() + pg_stat_get_checkpointer_num_requested()) > 0
    THEN ROUND(
      pg_stat_get_checkpointer_num_requested()::numeric /
      (pg_stat_get_checkpointer_num_timed() + pg_stat_get_checkpointer_num_requested()) * 100, 1)
    ELSE 0
  END AS requested_pct,
  pg_stat_get_bgwriter_stat_reset_time() AS stats_reset;
