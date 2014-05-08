-- @tag: requirement_spec_delete_trigger_fix2
-- @description: Fixes für Delete-Trigger bei Pflichtenheften
-- @depends: requirement_spec_delete_trigger_fix

-- requirement_spec_id: link to requirement specs (the versioned
-- document) working_copy_id: link to requirement spec working copy
-- (only set if working copy is currently at a version level)
ALTER TABLE requirement_spec_versions ADD COLUMN requirement_spec_id INTEGER;
ALTER TABLE requirement_spec_versions ADD COLUMN working_copy_id     INTEGER;

UPDATE requirement_spec_versions ver
SET requirement_spec_id = (
  SELECT MAX(rs.id)
  FROM requirement_specs rs
  WHERE rs.version_id = ver.id
);

UPDATE requirement_spec_versions ver
SET working_copy_id = (
  SELECT rs.id
  FROM requirement_specs rs
  WHERE (rs.version_id = ver.id)
    AND (rs.working_copy_id IS NULL)
);

ALTER TABLE requirement_spec_versions ALTER COLUMN requirement_spec_id SET NOT NULL;
ALTER TABLE requirement_spec_versions ADD FOREIGN KEY (requirement_spec_id) REFERENCES requirement_specs (id) ON DELETE CASCADE;
ALTER TABLE requirement_spec_versions ADD FOREIGN KEY (working_copy_id)     REFERENCES requirement_specs (id) ON DELETE CASCADE;

ALTER TABLE requirement_specs DROP COLUMN version_id;
ALTER TABLE requirement_specs DROP CONSTRAINT requirement_specs_working_copy_id_fkey;
ALTER TABLE requirement_specs ADD FOREIGN KEY (working_copy_id) REFERENCES requirement_specs (id) ON DELETE CASCADE;

ALTER TABLE requirement_spec_items DROP CONSTRAINT requirement_spec_items_requirement_spec_id_fkey;
ALTER TABLE requirement_spec_items ADD FOREIGN KEY (requirement_spec_id) REFERENCES requirement_specs (id) ON DELETE CASCADE;

ALTER TABLE requirement_spec_item_dependencies DROP CONSTRAINT requirement_spec_item_dependencies_depended_item_id_fkey;
ALTER TABLE requirement_spec_item_dependencies ADD FOREIGN KEY (depended_item_id) REFERENCES requirement_spec_items (id) ON DELETE CASCADE;
ALTER TABLE requirement_spec_item_dependencies DROP CONSTRAINT requirement_spec_item_dependencies_depending_item_id_fkey;
ALTER TABLE requirement_spec_item_dependencies ADD FOREIGN KEY (depending_item_id) REFERENCES requirement_spec_items (id) ON DELETE CASCADE;

ALTER TABLE requirement_spec_text_blocks DROP CONSTRAINT requirement_spec_text_blocks_requirement_spec_id_fkey;
ALTER TABLE requirement_spec_text_blocks ADD FOREIGN KEY (requirement_spec_id) REFERENCES requirement_specs (id) ON DELETE CASCADE;

-- Trigger for deleting depending stuff if a requirement spec is deleted.
CREATE OR REPLACE FUNCTION requirement_spec_delete_trigger() RETURNS trigger AS $$
  BEGIN
    IF TG_WHEN = 'AFTER' THEN
      DELETE FROM trigger_information WHERE (key = 'deleting_requirement_spec') AND (value = CAST(OLD.id AS TEXT));

      RETURN OLD;
    END IF;

    RAISE DEBUG 'before delete trigger on %', OLD.id;

    INSERT INTO trigger_information (key, value) VALUES ('deleting_requirement_spec', CAST(OLD.id AS TEXT));

    RAISE DEBUG '  Converting items into sections items for %', OLD.id;
    UPDATE requirement_spec_items SET item_type  = 'section', parent_id = NULL WHERE requirement_spec_id = OLD.id;

    RAISE DEBUG '  And we out for %', OLD.id;

    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

-- Trigger for deleting depending stuff if a requirement spec item is deleted.
CREATE OR REPLACE FUNCTION requirement_spec_item_before_delete_trigger() RETURNS trigger AS $$
  BEGIN
    RAISE DEBUG 'delete trig RSitem old id %', OLD.id;
    INSERT INTO trigger_information (key, value) VALUES ('deleting_requirement_spec_item', CAST(OLD.id AS TEXT));
    DELETE FROM requirement_spec_items WHERE (parent_id         = OLD.id);
    DELETE FROM trigger_information    WHERE (key = 'deleting_requirement_spec_item') AND (value = CAST(OLD.id AS TEXT));
    RAISE DEBUG 'delete trig END %', OLD.id;
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;
