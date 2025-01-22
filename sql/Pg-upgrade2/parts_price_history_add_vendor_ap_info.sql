-- @tag: parts_price_history_add_vendor_ap_info
-- @description: Lieferanten und Beleginfo für Preishistorie hinzufügen (falls bekannt)
-- @depends: parts_price_history_add_price_factor

ALTER TABLE parts_price_history ADD COLUMN vendor_id INTEGER;
ALTER TABLE parts_price_history ADD COLUMN ap_id INTEGER;

ALTER TABLE parts_price_history ADD FOREIGN KEY (vendor_id) REFERENCES vendor(id);
ALTER TABLE parts_price_history ADD FOREIGN KEY (ap_id) REFERENCES ap(id);
