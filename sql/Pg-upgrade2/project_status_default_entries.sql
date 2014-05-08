-- @tag: project_status_default_entries
-- @description: Standardeinträge für Projektstatus
-- @depends: project_bob_attributes_fix_project_status_table_name

INSERT INTO project_statuses (name, description, position) VALUES ('presales', 'Akquise',        1);
INSERT INTO project_statuses (name, description, position) VALUES ('planning', 'In Planung',     2);
INSERT INTO project_statuses (name, description, position) VALUES ('running',  'In Bearbeitung', 3);
INSERT INTO project_statuses (name, description, position) VALUES ('done',     'Fertiggestellt', 4);

UPDATE project
SET project_status_id = (
  SELECT id
  FROM project_statuses
  WHERE name = 'running'
)
WHERE project_status_id IS NULL;

ALTER TABLE project ALTER COLUMN project_status_id SET NOT NULL;
