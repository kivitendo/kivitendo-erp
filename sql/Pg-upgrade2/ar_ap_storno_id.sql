-- @tag: ar_ap_storno_id
-- @description: F&uuml;llen der Spalte 'storno_id' in den Tabellen 'ar' und 'ap'
-- @depends: ar_storno ap_storno
UPDATE ar SET storno_id =
  (SELECT id
   FROM ar ar2
   WHERE ar2.storno
     AND ('Storno zu ' || ar2.invnumber = ar.invnumber)
     AND (ar2.id < ar.id)
   ORDER BY id DESC
   LIMIT 1)
  WHERE storno
    AND (COALESCE(storno_id, 0) = 0)
    AND (invnumber   LIKE 'Storno zu %');

UPDATE ap SET storno_id =
  (SELECT id
   FROM ap ap2
   WHERE ap2.storno
     AND ('Storno zu ' || ap2.invnumber = ap.invnumber)
     AND (ap2.id < ap.id)
   ORDER BY id DESC
   LIMIT 1)
  WHERE storno
    AND (COALESCE(storno_id, 0) = 0)
    AND (invnumber   LIKE 'Storno zu %');
