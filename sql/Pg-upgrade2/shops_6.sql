-- @tag: shop_add_proxy
-- @description: Shop-Config um Option Proxy erweitert
-- @depends: shops_5
-- @ignore: 0

ALTER TABLE shops ADD COLUMN proxy TEXT default '';
