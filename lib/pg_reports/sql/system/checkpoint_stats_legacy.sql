-- Checkpoint and background writer statistics (PostgreSQL < 17)
-- All stats from pg_stat_bgwriter (before checkpoint columns were moved out)

SELECT
  checkpoints_timed,
  checkpoints_req AS checkpoints_requested,
  ROUND(checkpoint_write_time::numeric / 1000, 2) AS checkpoint_write_time_sec,
  ROUND(checkpoint_sync_time::numeric / 1000, 2) AS checkpoint_sync_time_sec,
  buffers_checkpoint,
  buffers_clean,
  maxwritten_clean AS bgwriter_stops,
  buffers_alloc,
  CASE
    WHEN (checkpoints_timed + checkpoints_req) > 0
    THEN ROUND(checkpoints_req::numeric / (checkpoints_timed + checkpoints_req) * 100, 1)
    ELSE 0
  END AS requested_pct,
  stats_reset
FROM pg_stat_bgwriter;
