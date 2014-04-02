-- @tag: requirement_spec_type_for_template_fix
-- @description: requirement_spec_type_for_template_fix
-- @depends: requirement_spec_types_number_formats
UPDATE requirement_specs
SET type_id = (
  SELECT MIN(id)
  FROM requirement_spec_types
)
WHERE type_id IS NULL;

ALTER TABLE requirement_specs ALTER COLUMN type_id SET NOT NULL;
