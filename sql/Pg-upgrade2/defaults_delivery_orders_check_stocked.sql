-- @tag: defaults_delivery_orders_check_stocked
-- @description: Mandantenkonfiguration: Prüfung, ob Lieferscheine ausgelagert sein müssen für den Workflow zur Rechnung
-- @depends: release_3_5_6_1

ALTER TABLE defaults ADD COLUMN sales_delivery_order_check_stocked    BOOLEAN DEFAULT FALSE;
ALTER TABLE defaults ADD COLUMN purchase_delivery_order_check_stocked BOOLEAN DEFAULT FALSE;
