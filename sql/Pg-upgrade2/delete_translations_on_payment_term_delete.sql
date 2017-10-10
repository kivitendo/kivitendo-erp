-- @tag: delete_translations_on_payment_term_delete
-- @description: Übersetzungen löschen, wenn Lieferbedingung gelöscht wird
-- @depends: payment_terms_translation2

CREATE OR REPLACE FUNCTION generic_translations_delete_on_payment_terms_delete_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    DELETE FROM generic_translations
      WHERE translation_id = OLD.id AND translation_type LIKE 'SL::DB::PaymentTerm/description_long';
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_delete_payment_term_trigger ON payment_terms;

CREATE TRIGGER after_delete_payment_term_trigger
  AFTER DELETE ON payment_terms
  FOR EACH ROW EXECUTE PROCEDURE generic_translations_delete_on_payment_terms_delete_trigger();

-- delete orphaned translations
DELETE FROM generic_translations
  WHERE translation_type LIKE 'SL::DB::PaymentTerm/description_long'
  AND   translation_id NOT IN (SELECT id FROM payment_terms);
