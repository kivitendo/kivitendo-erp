-- @tag: parts_ean_unique
-- @description: EAN in Artikel eindeutig machen
-- @depends: release_3_8_0
-- @ignore: 0

UPDATE parts SET ean = null where ean = '';
ALTER TABLE parts ADD CONSTRAINT parts_ean_unique UNIQUE(ean);
