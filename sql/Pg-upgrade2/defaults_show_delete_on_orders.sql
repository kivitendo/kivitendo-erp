-- @tag: defaults_show_delete_on_orders
-- @description: Einstellung, ob der "Löschen"-Knopf bei Aufträgen und Lieferscheinen angezeigt wird.
-- @depends: release_2_7_0

ALTER TABLE defaults ADD COLUMN sales_order_show_delete             boolean DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN purchase_order_show_delete          boolean DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN sales_delivery_order_show_delete    boolean DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN purchase_delivery_order_show_delete boolean DEFAULT TRUE;
