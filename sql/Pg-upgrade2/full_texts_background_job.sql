-- @tag: full_texts_background_job
-- @description: Hintergrundjob für tägliche Extraktion von Texten aus Dokumenten
-- @depends: release_3_6_0

INSERT INTO background_jobs (type, package_name, active, cron_spec, next_run_at)
VALUES ('interval', 'CreateOrUpdateFileFullTexts', true, '20 3 * * *',
  CAST(current_date AS timestamp) + CAST(
    (CASE
     WHEN extract('hour' FROM current_timestamp) < 2 THEN '3 hours 20 minutes'
     ELSE                                                 '1 day 3 hours 20 minutes'
     END) AS interval
  )
);
