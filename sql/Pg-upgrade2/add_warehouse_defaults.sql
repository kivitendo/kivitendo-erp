-- @tag: add_warehouse_defaults
-- @description: Standardlager und Lagerplatz in der Tabelle defaults. Sowie als ID-Verknüpfung in parts
-- @depends: release_3_0_0
ALTER TABLE defaults ADD COLUMN warehouse_id integer references warehouse(id);
ALTER TABLE defaults add column bin_id integer references bin(id);
ALTER TABLE parts ADD COLUMN warehouse_id integer references warehouse(id);
ALTER TABLE parts add column bin_id integer references bin(id);

