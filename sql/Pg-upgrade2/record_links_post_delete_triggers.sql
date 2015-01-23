-- @tag: record_links_post_delete_triggers
-- @description: Datenbankkonsistenz nach dem löschen von Belegen
-- @depends: release_2_7_0

-- When deleting records record_links weren't cleaned up until now
-- This wasn't really a problem apart from the fact that record_links slowly grew
-- but deleting records was seldom enough to not matter
-- Unfortunately delivery_plan decides if an order need to be displayed by the
-- number of record_links, which generates false negatives.
-- so, first clean up the database, and after that create triggers to
-- clean up automatically

DELETE FROM record_links WHERE from_table = 'oe' AND from_id NOT IN (SELECT id FROM oe);
DELETE FROM record_links WHERE to_table   = 'oe' AND to_id   NOT IN (SELECT id FROM oe);

DELETE FROM record_links WHERE from_table = 'delivery_orders' AND from_id NOT IN (SELECT id FROM delivery_orders);
DELETE FROM record_links WHERE to_table   = 'delivery_orders' AND to_id   NOT IN (SELECT id FROM delivery_orders);

DELETE FROM record_links WHERE from_table = 'ar' AND from_id NOT IN (SELECT id FROM ar);
DELETE FROM record_links WHERE to_table   = 'ar' AND to_id   NOT IN (SELECT id FROM ar);

DELETE FROM record_links WHERE from_table = 'ap' AND from_id NOT IN (SELECT id FROM ap);
DELETE FROM record_links WHERE to_table   = 'ap' AND to_id   NOT IN (SELECT id FROM ap);

CREATE OR REPLACE FUNCTION clean_up_record_links_before_oe_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'oe' AND from_id = OLD.id)
         OR (to_table   = 'oe' AND to_id   = OLD.id);
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clean_up_record_links_before_delivery_orders_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'delivery_orders' AND from_id = OLD.id)
         OR (to_table   = 'delivery_orders' AND to_id   = OLD.id);
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clean_up_record_links_before_ar_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'ar' AND from_id = OLD.id)
         OR (to_table   = 'ar' AND to_id   = OLD.id);
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clean_up_record_links_before_ap_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'ap' AND from_id = OLD.id)
         OR (to_table   = 'ap' AND to_id   = OLD.id);
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_delete_oe_trigger
BEFORE DELETE ON oe FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_oe_delete();

CREATE TRIGGER before_delete_delivery_orders_trigger
BEFORE DELETE ON delivery_orders FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_delivery_orders_delete();

CREATE TRIGGER before_delete_ar_trigger
BEFORE DELETE ON ar FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_ar_delete();

CREATE TRIGGER before_delete_ap_trigger
BEFORE DELETE ON ap FOR EACH ROW EXECUTE
PROCEDURE clean_up_record_links_before_ap_delete();
