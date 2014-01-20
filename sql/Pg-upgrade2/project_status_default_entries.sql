-- @tag: project_status_default_entries
-- @description: Standardeinträge für Projektstatus
-- @depends: project_bob_attributes

INSERT INTO project_status (name, description, position) VALUES ('presales', 'Akquise',        1);
INSERT INTO project_status (name, description, position) VALUES ('planning', 'In Planung',     2);
INSERT INTO project_status (name, description, position) VALUES ('running',  'In Bearbeitung', 3);
INSERT INTO project_status (name, description, position) VALUES ('done',     'Fertiggestellt', 4);
