-- @tag: project_types
-- @description: Tabelle für Projekttypen
-- @depends: release_3_0_0
CREATE TABLE project_types (
       id                       SERIAL,
       position                 INTEGER NOT NULL,
       description              TEXT,

       PRIMARY KEY (id)
);

INSERT INTO project_types (position, description) VALUES (1, 'Standard');
INSERT INTO project_types (position, description) VALUES (2, 'Festpreis');
INSERT INTO project_types (position, description) VALUES (3, 'Support');

ALTER TABLE project ADD COLUMN project_type_id INTEGER;
ALTER TABLE project ADD FOREIGN KEY (project_type_id) REFERENCES project_types (id);

UPDATE project SET project_type_id = (SELECT id FROM project_types WHERE description = 'Festpreis') WHERE type = 'Festpreis';
UPDATE project SET project_type_id = (SELECT id FROM project_types WHERE description = 'Support')   WHERE type = 'Support';
UPDATE project SET project_type_id = (SELECT id FROM project_types WHERE description = 'Standard')  WHERE project_type_id IS NULL;

ALTER TABLE project ALTER COLUMN project_type_id SET NOT NULL;
ALTER TABLE project DROP COLUMN type;
