-- @tag: delete_translations_on_delivery_term_delete
-- @description: Übersetzungen löschen, wenn Lieferbedingung gelöscht wird
-- @depends: delivery_terms

CREATE OR REPLACE FUNCTION generic_translations_delete_on_delivery_terms_delete_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    DELETE FROM generic_translations
      WHERE translation_id = OLD.id AND translation_type LIKE 'SL::DB::DeliveryTerm/description_long';
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_delete_delivery_term_trigger ON delivery_terms;

CREATE TRIGGER after_delete_delivery_term_trigger
  AFTER DELETE ON delivery_terms
  FOR EACH ROW EXECUTE PROCEDURE generic_translations_delete_on_delivery_terms_delete_trigger();

-- delete orphaned translations
DELETE FROM generic_translations
  WHERE translation_type LIKE 'SL::DB::DeliveryTerm/description_long'
  AND   translation_id NOT IN (SELECT id FROM delivery_terms);
