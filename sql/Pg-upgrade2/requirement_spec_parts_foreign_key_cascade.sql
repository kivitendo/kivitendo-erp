-- @tag: requirement_spec_parts_foreign_key_cascade
-- @description: Automatisches Löschen in requirement_spec_parts wenn zugehöriges Pflichtenheft gelöscht wird
-- @depends: requirement_spec_parts
ALTER TABLE requirement_spec_parts
DROP CONSTRAINT requirement_spec_parts_requirement_spec_id_fkey;

ALTER TABLE requirement_spec_parts
ADD FOREIGN KEY (requirement_spec_id) REFERENCES requirement_specs (id)
ON DELETE CASCADE;
