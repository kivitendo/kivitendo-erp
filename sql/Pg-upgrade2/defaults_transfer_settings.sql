-- @tag: defaults_transfer_settings
-- @description: Mandantenkonfiguration: Erzeugnis nur im gleichen Lager fertigen und Dienstleistungen für Auslagerstatus im Lieferschein ignorieren
-- @depends: release_3_5_6_1

ALTER TABLE defaults ADD COLUMN sales_delivery_order_check_service    BOOLEAN DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN purchase_delivery_order_check_service    BOOLEAN DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN produce_assembly_same_warehouse BOOLEAN DEFAULT TRUE;
