
-- @tag: defaults_bank_config
-- @description: Konfigurierbare Werte für Bank
-- @depends: release_3_9_0
ALTER TABLE defaults ADD COLUMN sepa_export_xml boolean DEFAULT true;
ALTER TABLE defaults ADD COLUMN no_bank_proposals boolean DEFAULT false;
