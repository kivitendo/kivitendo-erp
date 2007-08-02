-- @tag: price_factors
-- @description: Tabellen und Spalten f&uuml;r Preisfaktoren
-- @depends: release_2_4_3

CREATE TABLE price_factors (
  "id"  integer DEFAULT nextval('id'::text),
  "description" text,
  "factor" numeric(15,5),
  "sortkey" integer,

  PRIMARY KEY (id)
 );

ALTER TABLE parts ADD COLUMN price_factor_id integer;

ALTER TABLE invoice ADD COLUMN price_factor_id integer;
ALTER TABLE invoice ADD COLUMN price_factor numeric(15,5);
ALTER TABLE invoice ALTER COLUMN price_factor SET DEFAULT 1;
UPDATE invoice SET price_factor = 1;

ALTER TABLE invoice ADD COLUMN marge_price_factor numeric(15,5);
ALTER TABLE invoice ALTER COLUMN marge_price_factor SET DEFAULT 1;
UPDATE invoice SET marge_price_factor = 1;

ALTER TABLE orderitems ADD COLUMN price_factor_id integer;
ALTER TABLE orderitems ADD COLUMN price_factor numeric(15,5);
ALTER TABLE orderitems ALTER COLUMN price_factor SET DEFAULT 1;
UPDATE orderitems SET price_factor = 1;

ALTER TABLE orderitems ADD COLUMN marge_price_factor numeric(15,5);
ALTER TABLE orderitems ALTER COLUMN marge_price_factor SET DEFAULT 1;
UPDATE orderitems SET marge_price_factor = 1;

INSERT INTO price_factors (description, factor, sortkey) VALUES ('pro 10',      10, 1);
INSERT INTO price_factors (description, factor, sortkey) VALUES ('pro 100',    100, 2);
INSERT INTO price_factors (description, factor, sortkey) VALUES ('pro 1.000', 1000, 3);
