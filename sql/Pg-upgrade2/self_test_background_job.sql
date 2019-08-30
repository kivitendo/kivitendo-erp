-- @tag: self_test_background_job
-- @description: Hintergrundjob für tägliche Selbsttests
-- @depends: release_2_7_0
INSERT INTO background_jobs (type, package_name, active, cron_spec, next_run_at)
VALUES ('interval', 'SelfTest', true, '20 2 * * *',
  CAST(current_date AS timestamp) + CAST(
    (CASE
     WHEN extract('hour' FROM current_timestamp) < 2 THEN '2 hours 20 minutes'
     ELSE                                                 '1 day 2 hours 20 minutes'
     END) AS interval
  )
);
