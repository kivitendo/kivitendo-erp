-- @tag: requirement_spec_items_update_trigger_fix
-- @description: Fixes für Update-Trigger bei Pflichtenheft-Funktionsblöcken
-- @depends: requirement_specs

ALTER TABLE requirement_specs ADD COLUMN time_estimation NUMERIC(12, 2);
UPDATE requirement_specs
SET time_estimation = COALESCE((
  SELECT SUM(rsi.time_estimation)
  FROM requirement_spec_items rsi
  WHERE (rsi.parent_id IS NULL)
    AND (rsi.requirement_spec_id = requirement_specs.id)
), 0);
ALTER TABLE requirement_specs ALTER COLUMN time_estimation SET DEFAULT 0;
ALTER TABLE requirement_specs ALTER COLUMN time_estimation SET NOT NULL;

ALTER TABLE requirement_specs      DROP COLUMN net_sum;
ALTER TABLE requirement_spec_items DROP COLUMN net_sum;

-- Trigger for updating time_estimation of function blocks from their
-- children (not for sections, not for sub function blocks).
CREATE OR REPLACE FUNCTION update_requirement_spec_item_time_estimation(item_id INTEGER) RETURNS BOOLEAN AS $$
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
      WHERE (key   = 'deleting_requirement_spec_item')
        AND (value = CAST(item_id AS TEXT))
      LIMIT 1
    ) THEN
      RAISE DEBUG 'updateRSIE: item_id % is about to be deleted; do not update', item_id;
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
