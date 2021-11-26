-- @tag: linet_update_employee_base_data
-- @description: LINET: Hintergrundjob für regelmäßiges Aktualisieren der Employee-Basisdaten aus der Auth-Tabelle
-- @depends: release_3_5_6
INSERT INTO background_jobs (type, package_name, active, cron_spec, next_run_at)
VALUES ('interval', 'LSUpdateEmployeeBaseData', true, '*/5 * * * *', current_timestamp);
