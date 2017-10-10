-- @tag: shop_3
-- @description: Add columns itime and mtime and transaction_description for table shops
-- @depends: shops
-- @ignore: 0

ALTER TABLE shops ADD COLUMN transaction_description TEXT;
ALTER TABLE shops ADD COLUMN itime timestamp DEFAULT now();
ALTER TABLE shops ADD COLUMN mtime timestamp DEFAULT now();

CREATE TRIGGER mtime_shops
    BEFORE UPDATE ON shops
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();
