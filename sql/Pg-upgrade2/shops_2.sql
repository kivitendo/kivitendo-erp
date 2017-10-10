-- @tag: shop_2
-- @description: Add tables for part information for shop
-- @depends: shops
-- @ignore: 0

ALTER TABLE shops ADD COLUMN realm TEXT;
