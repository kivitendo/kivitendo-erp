-- @tag: customer_add_taxincluded_checked_2
-- @description: Datentype von taxincluded_checked ändern
-- @depends: customer_add_taxincluded_checked

ALTER TABLE customer DROP COLUMN taxincluded_checked;

ALTER TABLE customer ADD COLUMN taxincluded_checked boolean;
