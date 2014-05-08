-- @tag: requirement_spec_types_number_formats
-- @description: Nummerierungsformate für Pflichtenhefte in Typentabelle verschieben
-- @depends: requirement_specs
ALTER TABLE requirement_spec_types ADD   COLUMN section_number_format        TEXT;
ALTER TABLE requirement_spec_types ALTER COLUMN section_number_format        SET DEFAULT 'A00';
ALTER TABLE requirement_spec_types ADD   COLUMN function_block_number_format TEXT;
ALTER TABLE requirement_spec_types ALTER COLUMN function_block_number_format SET DEFAULT 'FB000';

UPDATE requirement_spec_types SET section_number_format        = (SELECT requirement_spec_section_number_format        FROM defaults);
UPDATE requirement_spec_types SET function_block_number_format = (SELECT requirement_spec_function_block_number_format FROM defaults);

ALTER TABLE requirement_spec_types ALTER COLUMN section_number_format        SET NOT NULL;
ALTER TABLE requirement_spec_types ALTER COLUMN function_block_number_format SET NOT NULL;

ALTER TABLE defaults DROP COLUMN requirement_spec_section_number_format;
ALTER TABLE defaults DROP COLUMN requirement_spec_function_block_number_format;
