-- @tag: shop_2
-- @description: Add tables for part information for shop
-- @charset: UTF-8
-- @depends: shops
-- @ignore: 0

ALTER TABLE shops ADD COLUMN realm TEXT;
