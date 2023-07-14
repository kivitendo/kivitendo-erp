-- @tag: defaults_allowed_documents_with_no_positions
-- @description: Mandantenkonfiguration für Belege, die ohne Positionen gespeichert werden können
-- @depends: release_3_8_0

ALTER TABLE defaults ADD COLUMN allowed_documents_with_no_positions TEXT[];
