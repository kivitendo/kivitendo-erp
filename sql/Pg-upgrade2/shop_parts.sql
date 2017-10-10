-- @tag: shop_parts
-- @description: Add tables for part information for shop
-- @depends: release_3_5_0 shops
-- @ignore: 0

CREATE TABLE shop_parts (
  id               SERIAL PRIMARY KEY,
  shop_id          INTEGER NOT NULL REFERENCES shops(id),
  part_id          INTEGER NOT NULL REFERENCES parts(id),
  shop_description TEXT,
  itime            TIMESTAMP DEFAULT now(),
  mtime            TIMESTAMP,
  last_update      TIMESTAMP,
  show_date        DATE,   -- the starting date for displaying part in shop
  sortorder        INTEGER,
  front_page       BOOLEAN NOT NULL DEFAULT false,
  active           BOOLEAN NOT NULL DEFAULT false,  -- rather than obsolete
  shop_category TEXT[][],
  active_price_source TEXT,
  metatag_keywords TEXT,
  metatag_description TEXT,
  metatag_title TEXT,
  UNIQUE (part_id, shop_id)  -- make sure a shop_part appears only once per shop and part
);

CREATE TRIGGER mtime_shop_parts BEFORE UPDATE ON shop_parts
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();
