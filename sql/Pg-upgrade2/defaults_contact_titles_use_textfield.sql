-- @tag: defaults_contact_titles_use_textfield
-- @description: Auswahl, ob Freitext-Feld für Titel von Ansprechpersonen im Kunden-/Lieferantenstamm angeboten wird
-- @depends: release_3_5_5

ALTER TABLE defaults ADD COLUMN contact_titles_use_textfield BOOLEAN;
UPDATE defaults SET contact_titles_use_textfield = TRUE;
