-- @tag: add_makemodel_prices
-- @description: EK-Preis zu jedem Lieferanten speichern und das Datum der Eingabe
-- @depends: release_2_6_1
ALTER TABLE makemodel ADD COLUMN lastcost  numeric(15,5) ;
ALTER TABLE makemodel ADD COLUMN lastupdate  date;
ALTER TABLE makemodel ADD COLUMN sortorder integer;

UPDATE makemodel SET sortorder = 1;

--# Da noch keine Daten vorhanden, den Wert "veralten"
UPDATE makemodel SET lastupdate = '1999-01-01';

