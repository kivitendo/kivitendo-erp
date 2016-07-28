-- @tag: remove_alternate_from_parts
-- @description: Veraltete Spalte »alternate« aus Tabelle »parts« entfernen
-- @depends: release_3_4_1
ALTER TABLE parts DROP COLUMN alternate;
