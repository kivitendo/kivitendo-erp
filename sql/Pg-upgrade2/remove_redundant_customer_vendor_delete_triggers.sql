-- @tag: remove_redundant_customer_vendor_delete_triggers
-- @description: Entfernt doppelte/falsche Trigger zum Aufräumen nach dem Löschen von Kunden/Lieferanten
-- @depends: release_3_1_0

-- drop triggers
DROP TRIGGER IF EXISTS del_customer ON customer;
DROP TRIGGER IF EXISTS del_vendor   ON vendor;

-- drop functions
DROP FUNCTION IF EXISTS del_customer();
DROP FUNCTION IF EXISTS del_vendor();
