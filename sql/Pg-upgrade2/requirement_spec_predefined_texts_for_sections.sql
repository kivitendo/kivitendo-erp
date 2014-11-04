-- @tag: requirement_spec_predefined_texts_for_sections
-- @description: Verwendung von vordefinierten Pflichtenhefttextblöcken bei Abschnitten
-- @depends: requirement_specs
ALTER TABLE requirement_spec_predefined_texts ADD COLUMN useable_for_text_blocks BOOLEAN;
ALTER TABLE requirement_spec_predefined_texts ADD COLUMN useable_for_sections    BOOLEAN;

UPDATE requirement_spec_predefined_texts
SET useable_for_text_blocks = TRUE, useable_for_sections = FALSE;

ALTER TABLE requirement_spec_predefined_texts ALTER COLUMN useable_for_text_blocks SET DEFAULT FALSE;
ALTER TABLE requirement_spec_predefined_texts ALTER COLUMN useable_for_sections    SET DEFAULT FALSE;

ALTER TABLE requirement_spec_predefined_texts ALTER COLUMN useable_for_text_blocks SET NOT NULL;
ALTER TABLE requirement_spec_predefined_texts ALTER COLUMN useable_for_sections    SET NOT NULL;
