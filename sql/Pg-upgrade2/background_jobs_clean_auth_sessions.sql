-- @tag: background_jobs_clean_auth_sessions
-- @description: Hintergrundjob zum Löschen abgelaufener Sessions
-- @depends: release_3_1_0
INSERT INTO background_jobs (type, package_name, active, cron_spec, next_run_at)
VALUES ('interval', 'CleanAuthSessions', true, '30 6 * * *',
  CAST(current_date AS timestamp) + CAST(
    (CASE
     WHEN extract('hour' FROM current_timestamp) < 6 THEN '6 hours 30 minutes'
     ELSE                                                 '1 day 6 hours 30 minutes'
     END) AS interval
  )
);
