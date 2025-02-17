-- @tag: sepa_export_items_vc_id
-- @description: Verknüpfe SEPA EXPORT ITEMS direkt mit vc
-- @depends: release_3_9_1

ALTER TABLE sepa_export_items  ADD COLUMN vendor_id   INTEGER REFERENCES vendor(id);
ALTER TABLE sepa_export_items  ADD COLUMN customer_id INTEGER REFERENCES customer(id);

UPDATE sepa_export_items set vendor_id = (SELECT vendor_id from ap where id = ap_id);
UPDATE sepa_export_items set customer_id = (SELECT customer_id from ar where id = ar_id);

