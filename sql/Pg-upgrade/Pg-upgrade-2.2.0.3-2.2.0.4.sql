CREATE TABLE units (
  name varchar(20) NOT NULL,
  base_unit varchar(20),
  factor bigint,

  PRIMARY KEY (name),
  FOREIGN KEY (base_unit) REFERENCES units (name)
);

INSERT INTO units (name, base_unit, factor) VALUES ('mg', NULL, NULL);
INSERT INTO units (name, base_unit, factor) VALUES ('g', 'mg', 1000);
INSERT INTO units (name, base_unit, factor) VALUES ('kg', 'g', 1000);
INSERT INTO units (name, base_unit, factor) VALUES ('t', 'kg', 1000);
INSERT INTO units (name, base_unit, factor) VALUES ('ml', NULL, NULL);
INSERT INTO units (name, base_unit, factor) VALUES ('L', 'ml', 1000);
INSERT INTO units (name, base_unit, factor) VALUES ('Stck', NULL, NULL);
ALTER TABLE units ADD COLUMN active boolean;
UPDATE units SET active = 't';
ALTER TABLE units ALTER COLUMN active SET DEFAULT 't';
ALTER TABLE units ALTER COLUMN active SET NOT NULL;

ALTER TABLE units ADD COLUMN tmp numeric(20, 5);
UPDATE units SET tmp = factor;
ALTER TABLE units DROP COLUMN factor;
ALTER TABLE units RENAME tmp TO factor;

ALTER TABLE units ADD COLUMN type varchar(20);
UPDATE units SET type = 'dimension';
ALTER TABLE units ALTER COLUMN type SET NOT NULL;

-- Einheitennamen duerfen 20 Zeichen lang sein.

ALTER TABLE parts ADD COLUMN tmp varchar(20);
UPDATE parts SET tmp = unit;
ALTER TABLE parts DROP COLUMN unit;
ALTER TABLE parts RENAME tmp TO unit;

ALTER TABLE invoice ADD COLUMN tmp varchar(20);
UPDATE invoice SET tmp = unit;
ALTER TABLE invoice DROP COLUMN unit;
ALTER TABLE invoice RENAME tmp TO unit;

ALTER TABLE orderitems ADD COLUMN tmp varchar(20);
UPDATE orderitems SET tmp = unit;
ALTER TABLE orderitems DROP COLUMN unit;
ALTER TABLE orderitems RENAME tmp TO unit;

-- Spalte "active" wird nicht mehr benoetigt, weil Einheiten nicht mehr deaktiviert
-- werden koennen.

ALTER TABLE units DROP COLUMN active;

