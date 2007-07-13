-- @tag: transaction_description
-- @description: Neue Spalte f&uuml;r ein Feld &quot;Vorgangsbezeichnung&quot; in Verkaufs- und Einkaufsmasken
-- @depends: release_2_4_2
ALTER TABLE ap ADD COLUMN transaction_description text;
ALTER TABLE ar ADD COLUMN transaction_description text;
ALTER TABLE oe ADD COLUMN transaction_description text;
