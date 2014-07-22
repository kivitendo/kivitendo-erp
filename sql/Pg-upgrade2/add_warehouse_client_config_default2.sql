-- @tag: add_warehouse_client_config_default2
-- @description: Konfigurations-Option für das Standard-Auslager-Verfahren (Dienstleistung nicht berücksichtigen), war vorher nicht konfigurierbar
-- @depends: release_3_1_0 add_warehouse_defaults add_warehouse_client_config_default
ALTER TABLE defaults add column transfer_default_services boolean default true;
