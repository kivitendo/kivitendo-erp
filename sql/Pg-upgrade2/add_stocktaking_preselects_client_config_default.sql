-- @tag: add_stocktaking_preselects_client_config_default
-- @description: Konfigurations-Optionen für Vorbelegungen zur Inventur
-- @depends: warehouse
ALTER TABLE defaults ADD COLUMN stocktaking_warehouse_id INTEGER REFERENCES warehouse(id);
ALTER TABLE defaults ADD COLUMN stocktaking_bin_id       INTEGER REFERENCES bin(id);
ALTER TABLE defaults ADD COLUMN stocktaking_cutoff_date  DATE;
