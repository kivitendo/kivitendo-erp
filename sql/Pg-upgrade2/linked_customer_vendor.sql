-- @tag: linked_customer_vendor
-- @description: Verbundene Kunden/Lieferanten
-- @depends: release_3_9_2

CREATE TABLE customer_vendor_links (
  customer_id INTEGER NOT NULL REFERENCES customer(id) ON DELETE CASCADE UNIQUE,
  vendor_id   INTEGER NOT NULL REFERENCES vendor(id) ON DELETE CASCADE UNIQUE,

  PRIMARY KEY (customer_id, vendor_id)
);


