-- @tag: defaults_add_parts_check_ean_unique
-- @description: Einstellung in der Mandantenkonfiguration, ob EAN-Codes gültiger Artikel beim Speichern eindeutig sein müssen
-- @depends: release_4_0_0
ALTER TABLE defaults ADD COLUMN parts_check_ean_unique BOOLEAN NOT NULL default true;

