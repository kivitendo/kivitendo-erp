-- @tag: delete_from_generic_translations_on_language_deletion
-- @description: Übersetzungen automatisch löschen, wenn die dazugehörige Sprache gelöscht wird
-- @depends: release_3_3_0
ALTER TABLE generic_translations
  DROP CONSTRAINT generic_translations_language_id_fkey,
  ADD CONSTRAINT generic_translations_language_id_fkey
    FOREIGN KEY (language_id)
    REFERENCES language (id)
    ON DELETE CASCADE;

DELETE FROM generic_translations
WHERE language_id NOT IN (
  SELECT id
  FROM language
);
