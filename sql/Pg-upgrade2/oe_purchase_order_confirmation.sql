-- @tag: oe_purchase_order_confirmation
-- @description: Neuer Einkaufsbeleg: Lieferantenauftragsbesätigung (purchase_order_confirmation)
-- @depends: release_3_8_0

ALTER TABLE defaults ADD pocnumber TEXT;
