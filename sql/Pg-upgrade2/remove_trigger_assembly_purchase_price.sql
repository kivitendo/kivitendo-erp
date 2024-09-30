-- @tag: remove_trigger_assembly_purchase_price
-- @description: Trigger zum Aktualisieren des EK-Preises bei Erzeugnissen entfernen
-- @depends: release_3_9_0

DROP TRIGGER  IF EXISTS trig_assembly_purchase_price ON assembly;
DROP FUNCTION IF EXISTS update_purchase_price();
