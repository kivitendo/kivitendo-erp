-- @tag: makemodel_add_vendor_foreign_key
-- @description: Makemodel make mit Lieferant verknüpft
-- @depends: release_3_4_1
-- @ignore: 0

ALTER TABLE makemodel ADD FOREIGN KEY (make) REFERENCES vendor(id);
