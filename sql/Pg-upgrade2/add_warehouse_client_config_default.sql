-- @tag: add_warehouse_client_config_default
-- @description: Konfigurations-Optionen für das Standard-Auslager-Verfahren
-- @depends: release_3_0_0 add_warehouse_defaults
ALTER TABLE defaults add column transfer_default boolean default true;
ALTER TABLE defaults add column transfer_default_use_master_default_bin boolean default false;
ALTER TABLE defaults add column transfer_default_ignore_onhand boolean default false;
ALTER TABLE defaults ADD COLUMN warehouse_id_ignore_onhand integer references warehouse(id);
ALTER TABLE defaults add column bin_id_ignore_onhand integer references bin(id);
