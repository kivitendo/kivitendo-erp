-- @tag: check_bin_belongs_to_wh_trigger
-- @description: Trigger, um sicher zu stellen, dass ein angegebener Lagerplatz auch zum Lager gehört.
-- @depends: delivery_orders warehouse

CREATE FUNCTION check_bin_belongs_to_wh() RETURNS "trigger"
  AS 'BEGIN
        IF NEW.bin_id IS NULL AND NEW.warehouse_id IS NULL THEN
          RETURN NEW;
        END IF;
        IF NEW.bin_id IN (SELECT id FROM bin WHERE warehouse_id = NEW.warehouse_id) THEN
          RETURN NEW;
        ELSE
          RAISE EXCEPTION ''bin (id=%) does not belong to warehouse (id=%).'', NEW.bin_id, NEW.warehouse_id;
          RETURN NULL;
        END IF;
      END;'
  LANGUAGE plpgsql;


CREATE TRIGGER check_bin_wh_delivery_order_items_stock BEFORE INSERT OR UPDATE ON delivery_order_items_stock
  FOR EACH ROW EXECUTE PROCEDURE check_bin_belongs_to_wh();

CREATE TRIGGER check_bin_wh_inventory BEFORE INSERT OR UPDATE ON inventory
  FOR EACH ROW EXECUTE PROCEDURE check_bin_belongs_to_wh();

CREATE TRIGGER check_bin_wh_parts BEFORE INSERT OR UPDATE ON parts
  FOR EACH ROW EXECUTE PROCEDURE check_bin_belongs_to_wh();
