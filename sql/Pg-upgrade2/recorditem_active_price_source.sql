-- @tag: recorditem_active_price_source
-- @description: Preisquelle in Belegpositionen
-- @depends: release_2_6_2
-- @encoding: utf-8

ALTER TABLE orderitems ADD COLUMN active_price_source TEXT NOT NULL DEFAULT '';
ALTER TABLE delivery_order_items ADD COLUMN active_price_source TEXT NOT NULL DEFAULT '';
ALTER TABLE invoice ADD COLUMN active_price_source TEXT NOT NULL DEFAULT '';
