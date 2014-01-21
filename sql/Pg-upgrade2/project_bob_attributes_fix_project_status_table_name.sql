-- @tag: project_bob_attributes_fix_project_status_table_name
-- @description: Tabellennamen project_status in project_statuses korrigieren
-- @depends: project_bob_attributes
ALTER TABLE project_status RENAME TO project_statuses;
