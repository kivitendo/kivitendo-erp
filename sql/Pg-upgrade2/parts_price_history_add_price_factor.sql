-- @tag: parts_price_history_add_price_factor
-- @description: Preisfaktor für Entwicklung der Stammdatenpreise
-- @depends: add_parts_price_history2

ALTER TABLE parts_price_history ADD COLUMN price_factor NUMERIC(15, 5) DEFAULT 1;

CREATE OR REPLACE FUNCTION add_parts_price_history_entry() RETURNS "trigger" AS $$
  BEGIN
    IF      (TG_OP = 'UPDATE')
        AND ((OLD.lastcost        IS NULL AND NEW.lastcost        IS NULL) OR (OLD.lastcost     = NEW.lastcost))
        AND ((OLD.listprice       IS NULL AND NEW.listprice       IS NULL) OR (OLD.listprice    = NEW.listprice))
        AND ((OLD.sellprice       IS NULL AND NEW.sellprice       IS NULL) OR (OLD.sellprice    = NEW.sellprice))
        AND ((OLD.price_factor_id IS NULL AND NEW.price_factor_id IS NULL) OR
             ( (SELECT factor FROM price_factors WHERE price_factors.id = OLD.price_factor_id) = (SELECT factor FROM price_factors WHERE price_factors.id = NEW.price_factor_id) ))
        THEN
      RETURN NEW;
    END IF;

    INSERT INTO parts_price_history (part_id, lastcost, listprice, sellprice, price_factor, valid_from)
    VALUES (NEW.id, NEW.lastcost, NEW.listprice, NEW.sellprice, COALESCE((SELECT factor FROM price_factors WHERE price_factors.id = NEW.price_factor_id), 1), now());

    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;
