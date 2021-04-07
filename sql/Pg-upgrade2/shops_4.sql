-- @tag: shop_4
-- @description: Add column default_shipping_costs_parts_id
-- @depends: shops
-- @ignore: 0

ALTER TABLE shops ADD COLUMN shipping_costs_parts_id integer;
