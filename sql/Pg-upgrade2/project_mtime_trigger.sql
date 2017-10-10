-- @tag: project_mtime_trigger
-- @description: mtime-Trigger für Tabelle project hinzufügen.
-- @depends: release_3_3_0

CREATE TRIGGER mtime_project BEFORE UPDATE ON project FOR EACH ROW EXECUTE PROCEDURE set_mtime();
