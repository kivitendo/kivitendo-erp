-- @tag: requirement_spec_items_price_factor
-- @description: Pflichtenheftabschnitte: Faktor für Verkaufspreis
-- @depends: requirement_specs
ALTER TABLE requirement_spec_items
  ADD COLUMN   sellprice_factor NUMERIC(10, 5),
  ALTER COLUMN sellprice_factor SET DEFAULT 1;

UPDATE requirement_spec_items
SET sellprice_factor = 1;
