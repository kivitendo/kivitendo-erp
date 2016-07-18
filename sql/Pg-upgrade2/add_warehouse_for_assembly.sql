-- @tag: add_warehouse_for_assembly
-- @description: Konfigurations-Option für das Fertigen von Erzeugnissen aus dem Standardlager
-- @depends: release_3_4_1 add_warehouse_defaults add_warehouse_client_config_default
ALTER TABLE defaults add column transfer_default_warehouse_for_assembly boolean default false;
