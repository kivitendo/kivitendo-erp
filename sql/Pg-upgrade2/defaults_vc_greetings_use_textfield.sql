-- @tag: defaults_vc_greetings_use_textfield
-- @description: Auswahl, ob Freitext-Feld für Anrede im Kunden-/Lieferantenstamm angeboten wird
-- @depends: release_3_5_5

ALTER TABLE defaults ADD COLUMN vc_greetings_use_textfield BOOLEAN;
UPDATE defaults SET vc_greetings_use_textfield = TRUE;
