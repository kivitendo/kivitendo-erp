-- @tag: records_add_buyer_id_recl
-- @description: Einkäufer für wirklich ALLE Belege hinzufügen
-- @depends: release_3_9_1
ALTER TABLE reclamations ADD COLUMN buyer_id INTEGER REFERENCES employee (id);

