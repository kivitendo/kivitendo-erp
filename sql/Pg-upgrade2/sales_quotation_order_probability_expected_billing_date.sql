-- @tag: sales_quotation_order_probability_expected_billing_date
-- @description: Weitere Felder im Angebot: Angebotswahrscheinlichkeit, voraussichtliches Abrechnungsdatum
ALTER TABLE oe
  ADD COLUMN order_probability     INTEGER,
  ADD COLUMN expected_billing_date DATE;

UPDATE oe SET order_probability = 0;

ALTER TABLE oe
  ALTER COLUMN order_probability SET DEFAULT 0,
  ALTER COLUMN order_probability SET NOT NULL;
