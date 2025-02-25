-- @tag: customer_vendor_add_buyer
-- @description: Einkäufer für Lieferant hinzugefügt
-- @depends: release_3_9_1
ALTER TABLE vendor ADD COLUMN buyer_id INTEGER REFERENCES employee (id);

