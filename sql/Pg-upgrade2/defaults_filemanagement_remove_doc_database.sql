-- @tag: defaults_filemanagement_remove_doc_database
-- @description: "Unbenutze Spalte für Dateimanagement-Speichertyp Datenbank entfernen"
-- @depends: filemanagement_feature

ALTER TABLE defaults DROP COLUMN doc_database;
