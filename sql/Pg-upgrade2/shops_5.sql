-- @tag: shops_5
-- @description: Shop-Config um Option zur direkten Beschreibungsübernahme erweitern
-- @depends: shop_4
-- @ignore: 0

ALTER TABLE shops ADD COLUMN use_part_longdescription BOOLEAN default false;
