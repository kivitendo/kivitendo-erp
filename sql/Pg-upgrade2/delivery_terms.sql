-- @tag: delivery_terms
-- @description: Neue Tabelle und Spalten für Lieferbedingungen
-- @depends: release_3_0_0

CREATE TABLE delivery_terms (
       id                        integer        NOT NULL DEFAULT nextval('id'),
       description               text,
       description_long          text,
       sortkey                   integer        NOT NULL,
       itime                     timestamp      DEFAULT now(),
       mtime                     timestamp,

       PRIMARY KEY (id)
);

CREATE TRIGGER mtime_delivery_terms
    BEFORE UPDATE ON delivery_terms
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();


ALTER TABLE oe                ADD COLUMN delivery_term_id integer;
ALTER TABLE oe                ADD FOREIGN KEY (delivery_term_id) REFERENCES delivery_terms(id);

ALTER TABLE delivery_orders   ADD COLUMN delivery_term_id integer;
ALTER TABLE delivery_orders   ADD FOREIGN KEY (delivery_term_id) REFERENCES delivery_terms(id);

ALTER TABLE ar                ADD COLUMN delivery_term_id integer;
ALTER TABLE ar                ADD FOREIGN KEY (delivery_term_id) REFERENCES delivery_terms(id);

ALTER TABLE ap                ADD COLUMN delivery_term_id integer;
ALTER TABLE ap                ADD FOREIGN KEY (delivery_term_id) REFERENCES delivery_terms(id);

ALTER TABLE customer          ADD COLUMN delivery_term_id integer;
ALTER TABLE customer          ADD FOREIGN KEY (delivery_term_id) REFERENCES delivery_terms(id);

ALTER TABLE vendor            ADD COLUMN delivery_term_id integer;
ALTER TABLE vendor            ADD FOREIGN KEY (delivery_term_id) REFERENCES delivery_terms(id);
