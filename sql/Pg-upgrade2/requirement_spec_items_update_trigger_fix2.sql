-- @tag: requirement_spec_items_update_trigger_fix2
-- @description: Fixes für Update-Trigger bei Pflichtenheften
-- @depends: requirement_spec_delete_trigger_fix

-- Trigger for updating time_estimation of function blocks from their
-- children. item_id is the ID of the item that needs to be updated
-- (or NULL if the requirement spec itself must be updated/a section
-- was changed).

-- This function must be dropped manually because PostgreSQL cannot
-- rename function parameters with 'CREATE OR REPLACE FUNCTION ...'
-- anymore.
DROP FUNCTION update_requirement_spec_item_time_estimation(item_id INTEGER, requirement_spec_id INTEGER);
CREATE FUNCTION update_requirement_spec_item_time_estimation(item_id INTEGER, item_requirement_spec_id INTEGER) RETURNS BOOLEAN AS $$
  DECLARE
    current_row RECORD;
    new_row     RECORD;
  BEGIN
    IF EXISTS(
      SELECT *
      FROM trigger_information
      WHERE ((key = 'deleting_requirement_spec_item') AND (value = CAST(item_id                  AS TEXT)))
         OR ((key = 'deleting_requirement_spec')      AND (value = CAST(item_requirement_spec_id AS TEXT)))
      LIMIT 1
    ) THEN
      RAISE DEBUG 'updateRSIE: item_id % or requirement_spec_id % is about to be deleted; do not update', item_id, item_requirement_spec_id;
      RETURN FALSE;
    END IF;

    -- item_id IS NULL means that a section has been updated. The
    -- requirement spec itself must therefore be updated.
    IF item_id IS NULL THEN
      SELECT COALESCE(time_estimation, 0) AS time_estimation
      INTO current_row
      FROM requirement_specs
      WHERE id = item_requirement_spec_id;

      SELECT COALESCE(SUM(time_estimation), 0) AS time_estimation
      INTO new_row
      FROM requirement_spec_items
      WHERE (parent_id IS NULL)
        AND (requirement_spec_id = item_requirement_spec_id);

      IF current_row.time_estimation <> new_row.time_estimation THEN
        RAISE DEBUG 'updateRSIE: updating requirement_spec % itself: old estimation % new %.', item_requirement_spec_id, current_row.time_estimation, new_row.time_estimation;

        UPDATE requirement_specs
        SET time_estimation = new_row.time_estimation
        WHERE id = item_requirement_spec_id;
      END IF;

      RETURN TRUE;
    END IF;

    -- If we're here it means that either a sub-function-block or a
    -- function-block has been updated. item_id is the parent's ID of
    -- the updated item -- meaning the ID of the item that needs to be
    -- updated now.

    SELECT COALESCE(time_estimation, 0) AS time_estimation
    INTO current_row
    FROM requirement_spec_items
    WHERE id = item_id;

    SELECT COALESCE(SUM(time_estimation), 0) AS time_estimation
    INTO new_row
    FROM requirement_spec_items
    WHERE (parent_id = item_id);

    IF current_row.time_estimation = new_row.time_estimation THEN
      RAISE DEBUG 'updateRSIE: item %: nothing to do', item_id;
      RETURN TRUE;
    END IF;

    RAISE DEBUG 'updateRSIE: updating item %: old estimation % new %.', item_id, current_row.time_estimation, new_row.time_estimation;

    UPDATE requirement_spec_items
    SET time_estimation = new_row.time_estimation
    WHERE id = item_id;

    RETURN TRUE;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION recalculate_spec_item_time_estimation(the_requirement_spec_id INTEGER) RETURNS BOOLEAN AS $$
  DECLARE
    item RECORD;
  BEGIN
    FOR item IN
      SELECT DISTINCT parent_id
      FROM requirement_spec_items
      WHERE (requirement_spec_id = the_requirement_spec_id)
        AND (item_type           = 'sub-function-block')
    LOOP
      RAISE DEBUG 'hmm function-block with sub: %', item.parent_id;
      PERFORM update_requirement_spec_item_time_estimation(item.parent_id, the_requirement_spec_id);
    END LOOP;

    FOR item IN
      SELECT DISTINCT parent_id
      FROM requirement_spec_items
      WHERE (requirement_spec_id = the_requirement_spec_id)
        AND (item_type           = 'function-block')
        AND (id NOT IN (
          SELECT parent_id
          FROM requirement_spec_items
          WHERE (requirement_spec_id = the_requirement_spec_id)
            AND (item_type           = 'sub-function-block')
        ))
    LOOP
      RAISE DEBUG 'hmm section with function-block: %', item.parent_id;
      PERFORM update_requirement_spec_item_time_estimation(item.parent_id, the_requirement_spec_id);
    END LOOP;

    PERFORM update_requirement_spec_item_time_estimation(NULL, the_requirement_spec_id);

    RETURN TRUE;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION recalculate_all_spec_item_time_estimations() RETURNS BOOLEAN AS $$
  DECLARE
    rspec RECORD;
  BEGIN
    FOR rspec IN SELECT id FROM requirement_specs LOOP
      PERFORM recalculate_spec_item_time_estimation(rspec.id);
    END LOOP;

    RETURN TRUE;
  END;
$$ LANGUAGE plpgsql;

SELECT recalculate_all_spec_item_time_estimations();
