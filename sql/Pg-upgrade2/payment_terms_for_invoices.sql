-- @tag: payment_terms_for_invoices
-- @description: Unterscheidung in Zahlungsbedingungen für Angebote/Aufträge und Rechnungen
-- @depends: release_3_4_0
ALTER TABLE payment_terms ADD COLUMN description_long_invoice TEXT;
UPDATE payment_terms SET description_long_invoice = description_long;

INSERT INTO generic_translations (translation_type, language_id, translation_id, translation)
SELECT translation_type || '_invoice', language_id, translation_id, translation
FROM generic_translations
WHERE translation_type = 'SL::DB::PaymentTerm/description_long';

CREATE OR REPLACE FUNCTION generic_translations_delete_on_payment_terms_delete_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    DELETE FROM generic_translations
    WHERE (translation_id = OLD.id)
      AND (translation_type IN ('SL::DB::PaymentTerm/description_long', 'SL::DB::PaymentTerm/description_long_invoice'));
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;
