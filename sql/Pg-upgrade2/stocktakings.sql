-- @tag: stocktakings
-- @description: Tabelle für in einer Inventur gezählte Artikel
-- @depends: warehouse release_3_5_1


CREATE TABLE stocktakings (
       id                       INTEGER        NOT NULL DEFAULT nextval('id'),
       inventory_id             INTEGER        REFERENCES inventory(id),
       warehouse_id             INTEGER        NOT NULL REFERENCES warehouse(id),
       bin_id                   INTEGER        NOT NULL REFERENCES bin(id),
       parts_id                 INTEGER        NOT NULL REFERENCES parts(id),
       employee_id              INTEGER        NOT NULL REFERENCES employee(id),
       qty                      NUMERIC(25,5)  NOT NULL ,
       comment                  TEXT,
       chargenumber             TEXT           NOT NULL DEFAULT '',
       bestbefore               DATE,
       cutoff_date              DATE           NOT NULL,
       itime                    TIMESTAMP      DEFAULT now(),
       mtime                    TIMESTAMP,

       PRIMARY KEY (id)
);

CREATE TRIGGER mtime_stocktakings BEFORE UPDATE ON stocktakings FOR EACH ROW EXECUTE PROCEDURE set_mtime();
