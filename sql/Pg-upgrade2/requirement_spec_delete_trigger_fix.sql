-- @tag: requirement_spec_delete_trigger_fix
-- @description: Fixes für Delete-Trigger bei Pflichtenheften
-- @depends: requirement_spec_items_update_trigger_fix

-- Trigger for updating time_estimation of function blocks from their
-- children (not for sections, not for sub function blocks).
CREATE OR REPLACE FUNCTION update_requirement_spec_item_time_estimation(item_id INTEGER, requirement_spec_id INTEGER) RETURNS BOOLEAN AS $$
  DECLARE
    item RECORD;
  BEGIN
    IF item_id IS NULL THEN
      RAISE DEBUG 'updateRSIE: item_id IS NULL';
      RETURN FALSE;
    END IF;

    IF EXISTS(
      SELECT *
      FROM trigger_information
      WHERE ((key = 'deleting_requirement_spec_item') AND (value = CAST(item_id             AS TEXT)))
         OR ((key = 'deleting_requirement_spec')      AND (value = CAST(requirement_spec_id AS TEXT)))
      LIMIT 1
    ) THEN
      RAISE DEBUG 'updateRSIE: item_id % or requirement_spec_id % is about to be deleted; do not update', item_id, requirement_spec_id;
      RETURN FALSE;
    END IF;

    SELECT * INTO item FROM requirement_spec_items WHERE id = item_id;
    RAISE DEBUG 'updateRSIE: item_id % item_type %', item_id, item.item_type;

    IF (item.item_type = 'sub-function-block') THEN
      -- Don't do anything for sub-function-blocks.
      RAISE DEBUG 'updateRSIE: this is a sub-function-block, not updating.';
      RETURN FALSE;
    END IF;

    RAISE DEBUG 'updateRSIE: will do stuff now';

    UPDATE requirement_spec_items
    SET time_estimation = COALESCE((
      SELECT SUM(time_estimation)
      FROM requirement_spec_items
      WHERE parent_id = item_id
    ), 0)
    WHERE id = item_id;

    IF (item.item_type = 'section') THEN
      RAISE DEBUG 'updateRSIE: updating requirement_spec % itself as well.', item.requirement_spec_id;
      UPDATE requirement_specs
      SET time_estimation = COALESCE((
        SELECT SUM(time_estimation)
        FROM requirement_spec_items
        WHERE (parent_id IS NULL)
          AND (requirement_spec_id = item.requirement_spec_id)
      ), 0);
    END IF;

    RETURN TRUE;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION requirement_spec_item_time_estimation_updater_trigger() RETURNS trigger AS $$
  DECLARE
    do_new BOOLEAN;
  BEGIN
    RAISE DEBUG 'updateRSITE op %', TG_OP;
    IF ((TG_OP = 'UPDATE') OR (TG_OP = 'DELETE')) THEN
      RAISE DEBUG 'UPDATE trigg op % OLD.id % OLD.parent_id %', TG_OP, OLD.id, OLD.parent_id;
      PERFORM update_requirement_spec_item_time_estimation(OLD.parent_id, OLD.requirement_spec_id);
      RAISE DEBUG 'UPDATE trigg op % END %', TG_OP, OLD.id;
    END IF;
    do_new = FALSE;

    IF (TG_OP = 'UPDATE') THEN
      do_new = OLD.parent_id <> NEW.parent_id;
    END IF;

    IF (do_new OR (TG_OP = 'INSERT')) THEN
      RAISE DEBUG 'UPDATE trigg op % NEW.id % NEW.parent_id %', TG_OP, NEW.id, NEW.parent_id;
      PERFORM update_requirement_spec_item_time_estimation(NEW.parent_id, NEW.requirement_spec_id);
      RAISE DEBUG 'UPDATE trigg op % END %', TG_OP, NEW.id;
    END IF;

    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_requirement_spec_item_time_estimation ON requirement_spec_items;
CREATE TRIGGER update_requirement_spec_item_time_estimation
AFTER INSERT OR UPDATE OR DELETE ON requirement_spec_items
FOR EACH ROW EXECUTE PROCEDURE requirement_spec_item_time_estimation_updater_trigger();


-- Trigger for deleting depending stuff if a requirement spec item is deleted.
CREATE OR REPLACE FUNCTION requirement_spec_item_before_delete_trigger() RETURNS trigger AS $$
  BEGIN
    RAISE DEBUG 'delete trig RSitem old id %', OLD.id;
    INSERT INTO trigger_information (key, value) VALUES ('deleting_requirement_spec_item', CAST(OLD.id AS TEXT));
    DELETE FROM requirement_spec_item_dependencies WHERE (depending_item_id = OLD.id) OR (depended_item_id = OLD.id);
    DELETE FROM requirement_spec_items             WHERE (parent_id         = OLD.id);
    DELETE FROM trigger_information                WHERE (key = 'deleting_requirement_spec_item') AND (value = CAST(OLD.id AS TEXT));
    RAISE DEBUG 'delete trig END %', OLD.id;
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS delete_requirement_spec_item_dependencies ON requirement_spec_items;
CREATE TRIGGER delete_requirement_spec_item_dependencies
BEFORE DELETE ON requirement_spec_items
FOR EACH ROW EXECUTE PROCEDURE requirement_spec_item_before_delete_trigger();


-- Trigger for deleting depending stuff if a requirement spec is deleted.
CREATE OR REPLACE FUNCTION requirement_spec_delete_trigger() RETURNS trigger AS $$
  DECLARE
    tname TEXT;
  BEGIN
    tname := 'tmp_delete_reqspec' || OLD.id;

    IF TG_WHEN = 'AFTER' THEN
      RAISE DEBUG 'after trigger on %; deleting from versions', OLD.id;
      EXECUTE 'DELETE FROM requirement_spec_versions ' ||
              'WHERE id IN (SELECT version_id FROM ' || tname || ')';

      RAISE DEBUG '  dropping table';
      EXECUTE 'DROP TABLE ' || tname;

      DELETE FROM trigger_information WHERE (key = 'deleting_requirement_spec') AND (value = CAST(OLD.id AS TEXT));

      RETURN OLD;
    END IF;

    RAISE DEBUG 'before delete trigger on %', OLD.id;

    INSERT INTO trigger_information (key, value) VALUES ('deleting_requirement_spec', CAST(OLD.id AS TEXT));

    EXECUTE 'CREATE TEMPORARY TABLE ' || tname || ' AS ' ||
      'SELECT DISTINCT version_id '     ||
      'FROM requirement_specs '         ||
      'WHERE (version_id IS NOT NULL) ' ||
      '  AND ((id = ' || OLD.id || ') OR (working_copy_id = ' || OLD.id || '))';

    RAISE DEBUG '  Updating version_id and items for %', OLD.id;
    UPDATE requirement_specs      SET version_id = NULL                        WHERE (id <> OLD.id) AND (working_copy_id = OLD.id);
    UPDATE requirement_spec_items SET item_type  = 'section', parent_id = NULL WHERE requirement_spec_id = OLD.id;

    RAISE DEBUG '  Deleting stuff for %', OLD.id;

    DELETE FROM requirement_spec_text_blocks WHERE (requirement_spec_id = OLD.id);
    DELETE FROM requirement_spec_items       WHERE (requirement_spec_id = OLD.id);
    DELETE FROM requirement_specs            WHERE (working_copy_id     = OLD.id);

    RAISE DEBUG '  And we out for %', OLD.id;

    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS delete_requirement_spec_dependencies ON requirement_specs;
CREATE TRIGGER delete_requirement_spec_dependencies
BEFORE DELETE ON requirement_specs
FOR EACH ROW EXECUTE PROCEDURE requirement_spec_delete_trigger();

DROP TRIGGER IF EXISTS after_delete_requirement_spec_dependencies ON requirement_specs;
CREATE TRIGGER after_delete_requirement_spec_dependencies
AFTER DELETE ON requirement_specs
FOR EACH ROW EXECUTE PROCEDURE requirement_spec_delete_trigger();

DROP FUNCTION IF EXISTS update_requirement_spec_item_time_estimation(item_id INTEGER);
