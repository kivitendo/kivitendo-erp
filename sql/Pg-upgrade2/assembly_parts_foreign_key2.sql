-- @tag: assembly_parts_foreign_key2
-- @description: Erzeugnis erhält Fremdschlüssel auf parts + NOT NULL in Tabelle assembly
-- @depends: assembly_parts_foreign_key
-- @ignore: 0

ALTER TABLE assembly ADD FOREIGN KEY (id) REFERENCES parts(id);
ALTER TABLE assembly ALTER COLUMN id SET NOT NULL;
