-- @tag: drop_datevexport
-- @description: Entfernen der Spalte datevexport in Tabelle vendor und customer. Dieser Status wird beim Datevexport überhaupt nicht berücksichtigt.
-- @depends: release_2_6_3
ALTER TABLE vendor DROP COLUMN datevexport;
ALTER TABLE customer DROP COLUMN datevexport;
DROP TRIGGER vendor_datevexport on vendor;
DROP TRIGGER customer_datevexport on customer;
DROP FUNCTION set_datevexport();
