-- @tag: shops
-- @description: Tabelle für Shops
-- @depends: release_3_5_0 customer_klass_rename_to_pricegroup_id_and_foreign_key
-- @ignore: 0

CREATE TABLE shops (
  id SERIAL PRIMARY KEY,
  description text,
  obsolete BOOLEAN NOT NULL DEFAULT false,
  sortkey INTEGER,
  connector text,     -- hardcoded options, e.g. xtcommerce, shopware
  pricetype text,     -- netto/brutto
  price_source text,  -- sellprice/listprice/lastcost or pricegroup id
  taxzone_id INTEGER,
  last_order_number INTEGER,
  orders_to_fetch INTEGER,
  url text,
  port INTEGER,
  login text,  -- "user" is reserved
  password text
);
