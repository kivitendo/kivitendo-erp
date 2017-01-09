-- @tag: create_part_customerprices
-- @description: VK-Preis für jeden Kunden speichern und das Datum der Eingabe
-- @depends: release_3_5_1

CREATE TABLE part_customer_prices (
  id          SERIAL PRIMARY KEY,
  parts_id    integer NOT NULL,
  customer_id integer NOT NULL,
  customer_partnumber text DEFAULT '',
  price      numeric(15,5) DEFAULT 0,
  sortorder  integer DEFAULT 0,
  lastupdate date DEFAULT now(),

  FOREIGN KEY (parts_id)    REFERENCES parts (id),
  FOREIGN KEY (customer_id) REFERENCES customer (id)
);
CREATE INDEX part_customer_prices_parts_id_key    ON part_customer_prices USING btree (parts_id);
CREATE INDEX part_customer_prices_customer_id_key ON part_customer_prices USING btree (customer_id);
