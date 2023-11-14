-- @tag: oe_delivery_orders_add_vendor_confirmation_number
-- @description: Auftragsbestätigungs-Nummer des Lieferanten für Aufträge und Lieferscheine
-- @depends: release_3_8_0

ALTER TABLE oe              ADD COLUMN vendor_confirmation_number TEXT;
ALTER TABLE delivery_orders ADD COLUMN vendor_confirmation_number TEXT;
