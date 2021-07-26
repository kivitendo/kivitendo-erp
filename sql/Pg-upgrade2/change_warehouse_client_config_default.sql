-- @tag: change_warehouse_client_config_default
-- @description: Konfigurations-Optionen für das Standard-Auslager-Verfahren zurückschrauben für negative Lagermengen
-- @depends: release_3_5_7
UPDATE defaults set transfer_default_ignore_onhand = 'f';
