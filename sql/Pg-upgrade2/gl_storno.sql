-- @tag: gl_storno
-- @description: Spalten f&uuml;r Dialogbuchen zum Speichern, ob diese Buchung storniert wurde bzw. f&uuml;r welche andere Buchung diese eine Stornobuchung ist
-- @depends: release_2_4_2
ALTER TABLE gl ADD COLUMN storno boolean;
ALTER TABLE gl ALTER COLUMN storno SET DEFAULT 'f';

ALTER TABLE gl ADD COLUMN storno_id integer;
ALTER TABLE gl ADD FOREIGN KEY (storno_id) REFERENCES gl (id);

UPDATE gl SET storno = 'f';

UPDATE gl SET storno = 't'
  WHERE (reference  LIKE 'Storno-%')
   AND (description LIKE 'Storno-%')
   AND EXISTS
     (SELECT gl2.id
      FROM gl gl2
      WHERE ('Storno-' || gl2.reference   = gl.reference)
        AND ('Storno-' || gl2.description = gl.description)
        AND (gl2.id < gl.id));

UPDATE gl SET storno = 't'
  WHERE (reference   NOT LIKE 'Storno-%')
    AND (description NOT LIKE 'Storno-%')
    AND EXISTS
    (SELECT gl2.id
     FROM gl gl2
     WHERE ('Storno-' || gl.reference   = gl2.reference)
       AND ('Storno-' || gl.description = gl2.description)
       AND (gl2.id > gl.id));

UPDATE gl SET storno_id =
  (SELECT id
   FROM gl gl2
   WHERE ('Storno-' || gl2.reference   = gl.reference)
     AND ('Storno-' || gl2.description = gl.description)
     AND (gl2.id < gl.id)
   ORDER BY itime
   LIMIT 1)
  WHERE storno
    AND (reference   LIKE 'Storno-%')
    AND (description LIKE 'Storno-%');
