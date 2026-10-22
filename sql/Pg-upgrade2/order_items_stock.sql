-- @tag: order_items_stock
-- @description: Lagerinfo (Vorauswahl) für Aufträge
-- @depends: release_4_1_0

CREATE TABLE order_items_stock (
       id                      SERIAL PRIMARY KEY,
       order_item_id           INTEGER               NOT NULL REFERENCES orderitems(id) ON DELETE CASCADE,
       qty                     NUMERIC(25,5)         NOT NULL,
       unit                    CHARACTER VARYING(20) NOT NULL REFERENCES units(name),
       warehouse_id            INTEGER               NOT NULL REFERENCES warehouse(id)  ON DELETE RESTRICT,
       bin_id                  INTEGER               NOT NULL REFERENCES bin(id)        ON DELETE RESTRICT,
       chargenumber            TEXT,
       bestbefore              DATE,
       itime                   TIMESTAMP             NOT NULL DEFAULT now(),
       mtime                   TIMESTAMP
);

CREATE TRIGGER order_items_stock BEFORE UPDATE ON order_items_stock FOR EACH ROW EXECUTE PROCEDURE set_mtime();
