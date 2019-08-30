-- @tag: periodic_invoices_background_job
-- @description: Hintergrundjob zum Erzeugen wiederkehrender Rechnungen
-- @depends: periodic_invoices
INSERT INTO background_jobs (type, package_name, active, cron_spec, next_run_at)
VALUES ('interval', 'CreatePeriodicInvoices', true, '0 3 1 * *',
        date_trunc('month', current_date) + CAST('1 month 3 hours' AS interval));
