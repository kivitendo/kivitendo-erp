-- @tag: cleanup_after_customer_vendor_deletion
-- @description: Nach Löschen von Kunden/Lieferanten via Trigger auch Ansprechpersonen/Lieferadressen löschen
-- @depends: release_3_0_0
CREATE OR REPLACE FUNCTION clean_up_after_customer_vendor_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM contacts
    WHERE cp_cv_id = OLD.id;

    DELETE FROM shipto
    WHERE (trans_id = OLD.id)
      AND (module   = 'CT');

    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER after_delete_customer_trigger
AFTER DELETE ON customer FOR EACH ROW EXECUTE
PROCEDURE clean_up_after_customer_vendor_delete();

CREATE TRIGGER after_delete_vendor_trigger
AFTER DELETE ON vendor FOR EACH ROW EXECUTE
PROCEDURE clean_up_after_customer_vendor_delete();
