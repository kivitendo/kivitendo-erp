-- @tag: clean_up_record_links_before_delete_trigger
-- @description: delete trigger for record_links clean up
-- @depends: release_3_5_7

CREATE OR REPLACE FUNCTION clean_up_record_links_before_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = TG_TABLE_NAME AND from_id = OLD.id)
         OR (to_table   = TG_TABLE_NAME AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;
