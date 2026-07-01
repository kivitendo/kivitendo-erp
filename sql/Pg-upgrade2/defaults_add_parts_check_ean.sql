-- @tag: defaults_add_parts_check_ean
-- @description: Einstellung in der Mandantenkonfiguration, ob EAN-Codes gültiger Artikel beim Speichern geprüft werden (Eindeutigkeit und Prüfziffer)
-- @depends: release_4_0_0
ALTER TABLE defaults ADD COLUMN parts_check_ean BOOLEAN NOT NULL default true;

