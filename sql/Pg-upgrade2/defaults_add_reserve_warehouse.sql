-- @tag: defaults_add_reserve_warehouse
-- @description: Mandantenkonfiguration für Sperrlager
-- @depends: release_4_0_0

ALTER TABLE defaults ADD COLUMN reserve_warehouse_id INTEGER REFERENCES warehouse(id) ON DELETE SET NULL;
