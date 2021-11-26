-- @tag: update_employee_base_data
-- @description: Hintergrundjob für regelmäßiges Aktualisieren der Employee-Basisdaten aus der Auth-Tabelle
-- @depends: release_3_6_0
INSERT INTO background_jobs (type, package_name, active, cron_spec, next_run_at)
VALUES ('interval', 'UpdateEmployeeBaseData', true, '*/5 * * * *', current_timestamp);
