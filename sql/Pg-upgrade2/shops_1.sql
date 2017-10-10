-- @tag: shop_1
-- @description: Add tables for part information for shop
-- @depends: shops
-- @ignore: 0

ALTER TABLE shops ADD COLUMN protocol TEXT NOT NULL DEFAULT 'http';
ALTER TABLE shops ADD COLUMN path TEXT NOT NULL DEFAULT '/';
ALTER TABLE shops RENAME COLUMN url TO server;
