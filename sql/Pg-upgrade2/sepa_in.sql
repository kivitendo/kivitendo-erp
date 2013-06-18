-- @tag: sepa_in
-- @description: Erweiterung SEPA für Kontoeinzüge
-- @depends: release_2_6_1
ALTER TABLE sepa_export ADD COLUMN vc varchar(10);
UPDATE sepa_export SET vc = 'vendor';

ALTER TABLE sepa_export_items ALTER COLUMN ap_id DROP NOT NULL;
ALTER TABLE sepa_export_items ADD COLUMN ar_id integer;
ALTER TABLE sepa_export_items ADD FOREIGN KEY (ar_id) REFERENCES ar (id);
ALTER TABLE sepa_export_items RENAME vendor_iban TO vc_iban;
ALTER TABLE sepa_export_items RENAME vendor_bic TO vc_bic;
