-- @tag: background_job_change_create_periodic_invoices_to_daily
-- @description: Hintergrundjob zum Erzeugen periodischer Rechnungen täglich ausführen
-- @depends: release_3_0_0
UPDATE background_jobs
SET cron_spec   = '0 3 * * *',
    next_run_at = CAST(current_date AS timestamp) + CAST(
                    (CASE
                     WHEN extract('hour' FROM current_timestamp) < 3 THEN '3 hours'
                     ELSE                                                 '1 day 3 hours'
                     END) AS interval
                  )
WHERE package_name = 'CreatePeriodicInvoices';
