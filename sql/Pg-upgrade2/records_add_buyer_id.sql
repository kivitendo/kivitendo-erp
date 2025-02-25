-- @tag: records_add_buyer_id
-- @description: Einkäufer für alle Belege hinzufügen
-- @depends: release_3_9_1
ALTER TABLE oe ADD COLUMN buyer_id INTEGER REFERENCES employee (id);
ALTER TABLE delivery_orders ADD COLUMN buyer_id INTEGER REFERENCES employee (id);
ALTER TABLE ap ADD COLUMN buyer_id INTEGER REFERENCES employee (id);

