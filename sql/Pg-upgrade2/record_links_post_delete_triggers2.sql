-- @tag: record_links_post_delete_triggers2
-- @description: PL/PgSQL Syntax Fix
-- @depends: record_links_post_delete_triggers

CREATE OR REPLACE FUNCTION clean_up_record_links_before_oe_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'oe' AND from_id = OLD.id)
         OR (to_table   = 'oe' AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clean_up_record_links_before_delivery_orders_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'delivery_orders' AND from_id = OLD.id)
         OR (to_table   = 'delivery_orders' AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clean_up_record_links_before_ar_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'ar' AND from_id = OLD.id)
         OR (to_table   = 'ar' AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clean_up_record_links_before_ap_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM record_links
      WHERE (from_table = 'ap' AND from_id = OLD.id)
         OR (to_table   = 'ap' AND to_id   = OLD.id);
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;
