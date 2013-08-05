-- @tag: requirement_spec_types_template_file_name
-- @description: Pflichtenhefttypen: Spalte für Druckvorlagendateinamen
-- @depends: requirement_specs
ALTER TABLE requirement_spec_types ADD COLUMN template_file_name TEXT;
UPDATE requirement_spec_types SET template_file_name = 'requirement_spec';
