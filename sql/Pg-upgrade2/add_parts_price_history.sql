-- @tag: add_parts_price_history
-- @description: Tabelle für Entwicklung der Stammdatenpreise
-- @depends: release_3_4_0
DROP TRIGGER  IF EXISTS add_parts_price_history_entry_after_changes_on_parts ON parts;
DROP FUNCTION IF EXISTS add_parts_price_history_entry();
DROP TABLE    IF EXISTS parts_price_history;

CREATE TABLE parts_price_history (
  id         SERIAL,
  part_id    INTEGER   NOT NULL,
  valid_from TIMESTAMP NOT NULL,
  lastcost   NUMERIC(15, 5),
  listprice  NUMERIC(15, 5),
  sellprice  NUMERIC(15, 5),

  PRIMARY KEY (id),
  FOREIGN KEY (part_id) REFERENCES parts (id) ON DELETE CASCADE
);

INSERT INTO parts_price_history (part_id, valid_from, lastcost, listprice, sellprice)
SELECT id, COALESCE(COALESCE(mtime, itime), now()), lastcost, listprice, sellprice
FROM parts;

CREATE FUNCTION add_parts_price_history_entry() RETURNS "trigger" AS $$
  BEGIN
    IF (TG_OP = 'UPDATE') AND (OLD.lastcost = NEW.lastcost) AND (OLD.listprice = NEW.listprice) AND (OLD.sellprice = NEW.sellprice) THEN
      RETURN NEW;
    END IF;

    INSERT INTO parts_price_history (part_id, lastcost, listprice, sellprice, valid_from)
    VALUES (NEW.id, NEW.lastcost, NEW.listprice, NEW.sellprice, now());

    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER add_parts_price_history_entry_after_changes_on_parts
AFTER INSERT OR UPDATE on parts
FOR EACH ROW EXECUTE PROCEDURE add_parts_price_history_entry();
