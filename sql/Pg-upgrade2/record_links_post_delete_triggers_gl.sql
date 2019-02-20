-- @tag: record_links_post_delete_triggers_gl2
-- @description: Datenbankkonsistenz record_links nach Löschen von Dialogbuchungen und Briefen
-- @depends: release_3_5_3

-- When deleting records record_links weren't cleaned up until now
-- This wasn't really a problem apart from the fact that record_links slowly grew
-- but deleting records was seldom enough to not matter
-- Unfortunately delivery_plan decides if an order need to be displayed by the
-- number of record_links, which generates false negatives.
-- so, first clean up the database, and after that create triggers to
-- clean up automatically

DELETE FROM record_links WHERE from_table = 'letter' AND from_id NOT IN (SELECT id FROM letter);
DELETE FROM record_links WHERE to_table   = 'letter' AND to_id   NOT IN (SELECT id FROM letter);

DELETE FROM record_links WHERE from_table = 'gl' AND from_id NOT IN (SELECT id FROM gl);
DELETE FROM record_links WHERE to_table   = 'gl' AND to_id   NOT IN (SELECT id FROM gl);

CREATE OR REPLACE FUNCTION clean_up_record_links_before_letter_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'letter' AND from_id = OLD.id)
         OR (to_table   = 'letter' AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clean_up_record_links_before_gl_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'gl' AND from_id = OLD.id)
         OR (to_table   = 'gl' AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER before_delete_gl_trigger
BEFORE DELETE ON gl FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_gl_delete();

CREATE TRIGGER before_delete_letter_trigger
BEFORE DELETE ON letter FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_letter_delete();
