-- @tag: project
-- @description: Spalte bei den Projekten zur Markierung auf aktiv/inaktiv
-- @depends: release_2_4_1
ALTER TABLE project ADD COLUMN active boolean;
ALTER TABLE project ALTER COLUMN active SET DEFAULT 't';
UPDATE project SET active = 't';
