-- @tag: defaults_contact_departments_use_textfield
-- @description: Auswahl, ob Freitext-Feld für Abteilungen bei Ansprechpersonen im Kunden-/Lieferantenstamm angeboten wird
-- @depends: release_3_5_5

ALTER TABLE defaults ADD COLUMN contact_departments_use_textfield BOOLEAN;
UPDATE defaults SET contact_departments_use_textfield = TRUE;
