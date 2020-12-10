-- @tag: customer_vendor_routing_id
-- @description: Kundenstammdaten: Feld »Unsere Leitweg-ID beim Kunden«
-- @depends: release_3_5_6
ALTER TABLE customer
ADD COLUMN c_vendor_routing_id TEXT;
