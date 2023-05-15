-- @tag: add_business_models_position
-- @description: Reihenfolge für Kunden-/Lieferantentyp-Artikelnummern
-- @depends: add_business_models

ALTER TABLE business_models ADD COLUMN position INTEGER;
