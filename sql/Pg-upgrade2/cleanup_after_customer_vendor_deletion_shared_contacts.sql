-- @tag: cleanup_after_customer_vendor_deletion_shared_contacts
-- @description: Nach Löschen von Kunden/Lieferanten via Trigger auch Lieferadressen löschen, aber keine Ansprechpersonen
-- @depends: shared_contacts
CREATE OR REPLACE FUNCTION clean_up_after_customer_vendor_delete() RETURNS trigger AS $$
  BEGIN
    DELETE FROM shipto
    WHERE (trans_id = OLD.id)
      AND (module   = 'CT');

    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;
