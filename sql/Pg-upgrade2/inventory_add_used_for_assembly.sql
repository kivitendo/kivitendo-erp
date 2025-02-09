-- @tag: inventory_add_used_for_assembly
-- @description: parts_id für das erzeugnis, was mit der trans_id gefertigt worden ist
-- @depends: release_3_9_1

ALTER TABLE inventory ADD COLUMN used_for_assembly_id integer;

ALTER TABLE inventory ADD FOREIGN KEY (used_for_assembly_id) REFERENCES parts (id);

CREATE INDEX inventory_assembly_id_idx ON inventory (used_for_assembly_id);


