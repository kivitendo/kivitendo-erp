-- @tag: record_links_dunning_post_delete_trigger
-- @description: Verknüpfte Belege für Mahnungen beim Löschen entfernen
-- @depends: release_3_5_6_1

-- clean up old dangling links
DELETE FROM record_links WHERE from_table = 'dunning' AND NOT EXISTS (SELECT id FROM dunning WHERE id = from_id);
DELETE FROM record_links WHERE to_table   = 'dunning' AND NOT EXISTS (SELECT id FROM dunning WHERE id = to_id);

-- install a trigger to delete links on delete
CREATE OR REPLACE FUNCTION clean_up_record_links_before_dunning_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'dunning' AND from_id = OLD.id)
         OR (to_table   = 'dunning' AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_delete_dunning_trigger
BEFORE DELETE ON dunning FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_dunning_delete();
