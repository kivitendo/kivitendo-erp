-- @tag:  parts_price_history_add_vc_arap_info
-- @description: Kunden/Lieferanten und Beleginfo für Preishistorie hinzufügen (falls bekannt)
-- @depends: parts_price_history_add_price_factor

ALTER TABLE parts_price_history ADD COLUMN vendor_id INTEGER;
ALTER TABLE parts_price_history ADD COLUMN customer_id INTEGER;
ALTER TABLE parts_price_history ADD COLUMN ar_id INTEGER;
ALTER TABLE parts_price_history ADD COLUMN ap_id INTEGER;

ALTER TABLE parts_price_history ADD FOREIGN KEY (vendor_id) REFERENCES vendor(id);
ALTER TABLE parts_price_history ADD FOREIGN KEY (customer_id) REFERENCES customer(id);
ALTER TABLE parts_price_history ADD FOREIGN KEY (ar_id) REFERENCES ar(id);
ALTER TABLE parts_price_history ADD FOREIGN KEY (ap_id) REFERENCES ap(id);
