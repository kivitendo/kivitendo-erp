-- @tag: customer_add_generic_mail_delivery
-- @description: Lieferschein (generischer E-Mail-Empfänger)
-- @depends: release_3_5_3
ALTER TABLE customer ADD COLUMN delivery_order_mail text;

