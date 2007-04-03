-- @tag: dunning_dunning_id
-- @description: In der Tabelle dunning ist dunning_id falsch benannt und es fehlt eine Spalte, die mehrere Eintr&auml;ge zusammenfasst.
-- @depends: release_2_4_2
ALTER TABLE dunning ADD COLUMN dunning_config_id integer;
UPDATE dunning SET dunning_config_id = dunning_id;
ALTER TABLE dunning ADD FOREIGN KEY (dunning_config_id) REFERENCES dunning_config (id);

ALTER TABLE dunning ADD COLUMN itime timestamp;
ALTER TABLE dunning ALTER COLUMN itime SET DEFAULT now();
UPDATE dunning SET itime = now();

ALTER TABLE dunning ADD COLUMN mtime timestamp;
CREATE TRIGGER mtime_dunning
    BEFORE UPDATE ON dunning
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();

UPDATE dunning SET dunning_id = nextval('id');

ALTER TABLE ar RENAME COLUMN dunning_id TO dunning_config_id;
ALTER TABLE ar ADD FOREIGN KEY (dunning_config_id) REFERENCES dunning_config (id);
