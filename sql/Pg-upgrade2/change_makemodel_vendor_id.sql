-- @tag: change_makemodel_vendor_id
-- @description: Der Lieferant der Ware ist jetzt ein Auswahlfeld (vendor.id == makemodel.make) Falls eine Freitext-Eingabe existiert, die dem Namen entspricht, wird diese direkt angelegt.
-- @depends: release_2_4_3
UPDATE makemodel
SET make = 
  (SELECT vendor.id
   FROM vendor
   WHERE vendor.name ILIKE '%' || makemodel.make || '%'
   LIMIT 1)
WHERE COALESCE(makemodel.make, '') <> '';

