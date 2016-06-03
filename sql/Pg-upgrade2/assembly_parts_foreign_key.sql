-- @tag: assembly_parts_foreign_key
-- @description: Erzeugniselement (assembly) erhält Fremdschlüssel auf parts + NOT NULL
-- @depends: release_3_4_1
-- @ignore: 0

ALTER TABLE assembly ADD FOREIGN KEY (parts_id) REFERENCES parts(id);
ALTER TABLE assembly ALTER COLUMN parts_id SET NOT NULL;
