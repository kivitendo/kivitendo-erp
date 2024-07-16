-- @tag: stock_countings
-- @description: Tabellen für (Zwischen-)zählungen / Inventuren
-- @depends: warehouse release_3_9_0

CREATE TABLE stock_countings (
       id            INTEGER        NOT NULL DEFAULT nextval('id'),
       employee_id   INTEGER        NOT NULL REFERENCES employee(id),
       name          TEXT           NOT NULL UNIQUE,
       description   TEXT,
       bin_id        INTEGER        REFERENCES bin(id),
       part_id       INTEGER        REFERENCES parts(id),
       partsgroup_id INTEGER        REFERENCES partsgroup(id),
       vendor_id     INTEGER        REFERENCES vendor(id),
       itime         TIMESTAMP      DEFAULT now(),
       mtime         TIMESTAMP,

       PRIMARY KEY (id)
);

CREATE TRIGGER mtime_stock_countings BEFORE UPDATE ON stock_countings FOR EACH ROW EXECUTE PROCEDURE set_mtime();

CREATE TABLE stock_counting_items (
       id                      INTEGER        NOT NULL DEFAULT nextval('id'),
       counting_id             INTEGER        NOT NULL REFERENCES stock_countings(id),
       bin_id                  INTEGER        NOT NULL REFERENCES bin(id),
       part_id                 INTEGER        NOT NULL REFERENCES parts(id),
       employee_id             INTEGER        NOT NULL REFERENCES employee(id),
       counted_at              TIMESTAMP      NOT NULL DEFAULT now(),
       qty                     NUMERIC(25,5)  NOT NULL,
       comment                 TEXT,
       correction_inventory_id INTEGER        REFERENCES inventory(id),
       itime                   TIMESTAMP      NOT NULL DEFAULT now(),
       mtime                   TIMESTAMP,

       PRIMARY KEY (id)
);

CREATE TRIGGER mtime_stock_counting_items BEFORE UPDATE ON stock_counting_items FOR EACH ROW EXECUTE PROCEDURE set_mtime();
