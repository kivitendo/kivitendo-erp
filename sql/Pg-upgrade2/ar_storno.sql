-- @tag: ar_storno
-- @description: Spalten f&uuml;r Debitorenbuchen zum Speichern f&uuml;r welche andere Buchung diese eine Stornobuchung ist
-- @depends: release_2_4_2
ALTER TABLE ar ADD COLUMN storno_id integer;
ALTER TABLE ar ADD FOREIGN KEY (storno_id) REFERENCES ar (id);
