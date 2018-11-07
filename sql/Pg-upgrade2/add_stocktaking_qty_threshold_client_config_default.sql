-- @tag: add_stocktaking_qty_threshold_client_config_default
-- @description: Konfigurations-Option für Mengen-Schwellwert zur Inventur
-- @depends: add_stocktaking_preselects_client_config_default

ALTER TABLE defaults ADD COLUMN stocktaking_qty_threshold NUMERIC(25,5) DEFAULT 0;
