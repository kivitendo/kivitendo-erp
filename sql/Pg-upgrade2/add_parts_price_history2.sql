-- @tag: add_parts_price_history2
-- @description: Korrigierte Triggerfunktion für Entwicklung der Stammdatenpreise
-- @depends: add_parts_price_history
CREATE OR REPLACE FUNCTION add_parts_price_history_entry() RETURNS "trigger" AS $$
  BEGIN
    IF      (TG_OP = 'UPDATE')
        AND ((OLD.lastcost  IS NULL AND NEW.lastcost  IS NULL) OR (OLD.lastcost  = NEW.lastcost))
        AND ((OLD.listprice IS NULL AND NEW.listprice IS NULL) OR (OLD.listprice = NEW.listprice))
        AND ((OLD.sellprice IS NULL AND NEW.sellprice IS NULL) OR (OLD.sellprice = NEW.sellprice)) THEN
      RETURN NEW;
    END IF;

    INSERT INTO parts_price_history (part_id, lastcost, listprice, sellprice, valid_from)
    VALUES (NEW.id, NEW.lastcost, NEW.listprice, NEW.sellprice, now());

    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;
