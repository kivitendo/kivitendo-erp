-- @tag: ap_storno
-- @description: Spalten f&uuml;r Kreditorenbuchen zum Speichern f&uuml;r welche andere Buchung diese eine Stornobuchung ist
-- @depends: release_2_4_2
ALTER TABLE ap ADD COLUMN storno_id integer;
ALTER TABLE ap ADD FOREIGN KEY (storno_id) REFERENCES ap (id);
