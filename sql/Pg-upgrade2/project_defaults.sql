-- @tag: add_project_defaults
-- @description: Standardprojekttyp und Standardprojectstatus
-- @depends: release_3_3_0
ALTER TABLE defaults ADD COLUMN order_always_project boolean DEFAULT false;
ALTER TABLE defaults ADD COLUMN project_status_id integer;
ALTER TABLE defaults ADD COLUMN project_type_id integer;
ALTER TABLE defaults ADD FOREIGN KEY (project_status_id) REFERENCES project_statuses (id);
ALTER TABLE defaults ADD FOREIGN KEY (project_type_id) REFERENCES project_types (id);

