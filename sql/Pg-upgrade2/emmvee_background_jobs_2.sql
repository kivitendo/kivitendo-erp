-- @tag: emmvee_background_jobs_2
-- @description: Hintergrundjobs einrichten
-- @depends: emmvee_background_jobs
INSERT INTO background_jobs (type, package_name, active, cron_spec, next_run_at)
VALUES ('interval', 'CleanBackgroundJobHistory', true, '0 3 * * *',
  CAST(current_date AS timestamp) + CAST(
    (CASE
     WHEN extract('hour' FROM current_timestamp) < 3 THEN '3 hours'
     ELSE                                                 '1 day 3 hours'
     END) AS interval
  )
);
