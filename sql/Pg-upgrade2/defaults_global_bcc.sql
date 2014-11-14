-- @tag: defaults_global_bcc
-- @description: Konfigurierbare globale BCC-Adresse
-- @depends: release_3_1_0

ALTER TABLE defaults ADD COLUMN global_bcc TEXT DEFAULT '';
