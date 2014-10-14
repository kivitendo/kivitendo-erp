-- @tag: recorditem_active_record_source
-- @description: Preisquellen: Rabatte
-- @depends: release_3_1_0 recorditem_active_price_source
-- @encoding: utf-8

ALTER TABLE orderitems           ADD COLUMN active_discount_source TEXT NOT NULL DEFAULT '';
ALTER TABLE delivery_order_items ADD COLUMN active_discount_source TEXT NOT NULL DEFAULT '';
ALTER TABLE invoice              ADD COLUMN active_discount_source TEXT NOT NULL DEFAULT '';
