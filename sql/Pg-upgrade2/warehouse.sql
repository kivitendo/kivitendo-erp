-- @tag: warehouse
-- @description: Diverse neue Tabellen und Spalten zur Mehrlagerf&auml;higkeit
-- @depends: release_2_4_3

-- Tabelle "bin" für Lagerplätze.
CREATE TABLE bin (
  id integer NOT NULL DEFAULT nextval('id'),
  warehouse_id integer NOT NULL,
  description text,
  itime timestamp DEFAULT now(),
  mtime timestamp,

  PRIMARY KEY (id),
  FOREIGN KEY (warehouse_id) REFERENCES warehouse (id)
);

CREATE TRIGGER mtime_bin BEFORE UPDATE ON bin
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();

-- Tabelle "warehouse"
ALTER TABLE warehouse ADD COLUMN sortkey integer;
CREATE SEQUENCE tmp_counter;
UPDATE warehouse SET sortkey = nextval('tmp_counter');
DROP SEQUENCE tmp_counter;

ALTER TABLE warehouse ADD COLUMN invalid boolean;
UPDATE warehouse SET invalid = 'f';

CREATE TRIGGER mtime_warehouse BEFORE UPDATE ON warehouse
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();

-- Tabelle "transfer_type"
CREATE TABLE transfer_type (
  id integer NOT NULL DEFAULT nextval('id'),
  direction varchar(10) NOT NULL,
  description text,
  sortkey integer,
  itime timestamp DEFAULT now(),
  mtime timestamp,

  PRIMARY KEY (id)
);

CREATE TRIGGER mtime_transfer_type BEFORE UPDATE ON transfer_type
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();

INSERT INTO transfer_type (direction, description, sortkey) VALUES ('in', 'stock', 1);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('in', 'found', 2);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('in', 'correction', 3);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'used', 4);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'disposed', 5);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'back', 6);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'missing', 7);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('out', 'correction', 9);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('transfer', 'transfer', 10);
INSERT INTO transfer_type (direction, description, sortkey) VALUES ('transfer', 'correction', 11);

-- Anpassungen an "inventory".
DELETE FROM inventory;

ALTER TABLE inventory ADD COLUMN bin_id integer;
ALTER TABLE inventory ADD FOREIGN KEY (bin_id) REFERENCES bin (id);
ALTER TABLE inventory ALTER COLUMN bin_id SET NOT NULL;

ALTER TABLE inventory DROP COLUMN qty;
ALTER TABLE inventory ADD COLUMN qty numeric(25, 5);

ALTER TABLE inventory ALTER COLUMN parts_id SET NOT NULL;
ALTER TABLE inventory ADD FOREIGN KEY (parts_id) REFERENCES parts(id);

ALTER TABLE inventory ALTER COLUMN warehouse_id SET NOT NULL;
ALTER TABLE inventory ADD FOREIGN KEY (warehouse_id) REFERENCES warehouse(id);

ALTER TABLE inventory ALTER COLUMN employee_id SET NOT NULL;
ALTER TABLE inventory ADD FOREIGN KEY (employee_id) REFERENCES employee (id);

ALTER TABLE inventory ADD COLUMN trans_id integer;
ALTER TABLE inventory ALTER COLUMN trans_id SET NOT NULL;

ALTER TABLE inventory ADD COLUMN trans_type_id integer;
ALTER TABLE inventory ALTER COLUMN trans_type_id SET NOT NULL;
ALTER TABLE inventory ADD FOREIGN KEY (trans_type_id) REFERENCES transfer_type (id);

ALTER TABLE inventory ADD COLUMN project_id integer;
ALTER TABLE inventory ADD FOREIGN KEY (project_id) REFERENCES project (id);

ALTER TABLE inventory ADD COLUMN chargenumber text;
ALTER TABLE inventory ADD COLUMN comment text;

-- "onhand" in "parts" über einen Trigger automatisch berechnen lassen.
ALTER TABLE parts DROP COLUMN onhand;
ALTER TABLE parts ADD COLUMN onhand numeric(25,5);
UPDATE parts SET onhand = COALESCE((SELECT SUM(qty) FROM inventory WHERE inventory.parts_id = parts.id), 0);

ALTER TABLE parts ADD COLUMN stockable boolean;
ALTER TABLE parts ALTER COLUMN stockable SET DEFAULT 'f';
UPDATE parts SET stockable = 'f';

CREATE OR REPLACE FUNCTION update_onhand() RETURNS trigger AS '
BEGIN
  IF tg_op = ''INSERT'' THEN
    UPDATE parts SET onhand = COALESCE(onhand, 0) + new.qty WHERE id = new.parts_id;
    RETURN new;
  ELSIF tg_op = ''DELETE'' THEN
    UPDATE parts SET onhand = COALESCE(onhand, 0) - old.qty WHERE id = old.parts_id;
    RETURN old;
  ELSE
    UPDATE parts SET onhand = COALESCE(onhand, 0) - old.qty + new.qty WHERE id = old.parts_id;
    RETURN new;
  END IF;
END;
' LANGUAGE plpgsql;

CREATE TRIGGER trig_update_onhand
  AFTER INSERT OR UPDATE OR DELETE ON inventory
  FOR EACH ROW EXECUTE PROCEDURE update_onhand();

