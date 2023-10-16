-- @tag: parts_delete_trigger_priceupdate
-- @description: Trigger und Funktion zum Preisupdate der Tabelle parts entfernen
-- @depends: release_3_8_0

DROP TRIGGER IF EXISTS priceupdate_parts ON parts;
DROP FUNCTION set_priceupdate_parts;
