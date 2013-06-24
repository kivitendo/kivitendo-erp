-- @tag: ap_deliverydate
-- @description: deliverydate zu Einkaufsrechnung hinzufügen
-- @depends: release_3_0_0
ALTER TABLE ap ADD COLUMN deliverydate date;
