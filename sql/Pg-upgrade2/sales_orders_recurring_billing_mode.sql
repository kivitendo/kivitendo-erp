-- @tag: sales_orders_recurring_billing_mode
-- @description: Verkaufsaufträge: Positionen wiederkehrender Rechnungen optional nur einmal oder gar nicht abrechnen
-- @depends: release_3_6_0
CREATE TYPE items_recurring_billing_mode AS ENUM ('never', 'once', 'always');

ALTER TABLE orderitems
  ADD COLUMN recurring_billing_mode items_recurring_billing_mode DEFAULT 'always' NOT NULL,
  ADD COLUMN recurring_billing_invoice_id INTEGER,
  ADD FOREIGN KEY (recurring_billing_invoice_id) REFERENCES ar (id) ON DELETE SET NULL;
