-- @tag: delete_translations_on_tax_delete
-- @description: Übersetzungen löschen, wenn Steuer gelöscht wird
-- @depends: release_3_0_0

CREATE OR REPLACE FUNCTION generic_translations_delete_on_tax_delete_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    DELETE FROM generic_translations
      WHERE translation_id = OLD.id AND translation_type LIKE 'SL::DB::Tax/taxdescription';
    RETURN OLD;
  END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_delete_tax_trigger ON tax;

CREATE TRIGGER after_delete_tax_trigger
  AFTER DELETE ON tax
  FOR EACH ROW EXECUTE PROCEDURE generic_translations_delete_on_tax_delete_trigger();

-- delete orphaned translations
DELETE FROM generic_translations
  WHERE translation_type LIKE 'SL::DB::Tax/taxdescription'
  AND   translation_id NOT IN (SELECT id FROM tax);
