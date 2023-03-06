-- @tag: reclamation_type
-- @description: Persistente Typen in Reklamationen
-- @depends: release_3_7_0

CREATE TYPE reclamation_types AS ENUM (
  'sales_reclamation',
  'purchase_reclamation'
);

ALTER TABLE reclamations ADD COLUMN record_type reclamation_types;

UPDATE reclamations SET record_type = 'sales_reclamation' WHERE customer_id IS NOT NULL;
UPDATE reclamations SET record_type = 'purchase_reclamation' WHERE vendor_id IS NOT NULL;

ALTER TABLE reclamations ALTER COLUMN record_type SET NOT NULL;


