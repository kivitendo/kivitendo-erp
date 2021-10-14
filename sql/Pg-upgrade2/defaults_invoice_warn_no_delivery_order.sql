-- @tag: defaults_invoice_warn_no_delivery_order
-- @description: Mandantenkonfiguration: Warnung bei fehlendem Lieferschein als Vorgänger zur Rechnung
-- @depends: release_3_5_8

ALTER TABLE defaults ADD COLUMN warn_no_delivery_order_for_invoice BOOLEAN DEFAULT FALSE;
