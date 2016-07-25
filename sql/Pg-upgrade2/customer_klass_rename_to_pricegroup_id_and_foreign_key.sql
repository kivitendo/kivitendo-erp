-- @tag: customer_klass_rename_to_pricegroup_id_and_foreign_key
-- @description: klass nach pricegroup_id umbenannt
-- @depends: release_3_4_1
-- @ignore: 0

ALTER TABLE customer ADD COLUMN pricegroup_id INTEGER REFERENCES pricegroup (id);
UPDATE customer SET pricegroup_id = klass WHERE klass != 0;
ALTER TABLE customer DROP COLUMN klass;
