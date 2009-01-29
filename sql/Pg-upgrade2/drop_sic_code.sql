-- @tag: sic_code 
-- @description: Loescht alle Datenstrukturen die mit sic_code zu tun haben inkl. der Tabelle sic (Standard Industrial Classification) selber. Niemand kann in der aktuellen Version dieses Feld aendern.
-- @depends: release_2_4_3
DROP TABLE sic;
ALTER TABLE customer DROP COLUMN sic_code;
ALTER TABLE vendor DROP COLUMN  sic_code;
