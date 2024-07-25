-- @tag: periodic_invoices_items
-- @description: Separate Tabelle für Positionen von Wiederkehrende Rechnungen
-- @depends: periodic_invoices sales_orders_recurring_billing_mode
CREATE TABLE periodic_invoice_items_configs (
  order_item_id           INTEGER     NOT NULL  REFERENCES orderitems (id) ON DELETE CASCADE,
  periodicity             VARCHAR(10) NOT NULL,
  terminated              BOOLEAN,
  start_date              DATE,
  end_date                DATE,
  extend_automatically_by INTEGER,
  once_invoice_id         INTEGER               REFERENCES ar (id) ON DELETE SET NULL,

  PRIMARY KEY (order_item_id)
);

INSERT INTO periodic_invoice_items_configs (
  order_item_id, periodicity, once_invoice_id
) SELECT id, 'o', recurring_billing_invoice_id
FROM orderitems
WHERE recurring_billing_mode = 'once';

INSERT INTO periodic_invoice_items_configs (
  order_item_id, periodicity, once_invoice_id
) SELECT id, 'n', recurring_billing_invoice_id
FROM orderitems
WHERE recurring_billing_mode = 'never';

INSERT INTO periodic_invoice_items_configs (
  order_item_id, periodicity, once_invoice_id
) SELECT id, 'p', recurring_billing_invoice_id
FROM orderitems
WHERE recurring_billing_mode = 'always' and recurring_billing_invoice_id IS NOT NULL;

ALTER TABLE orderitems DROP COLUMN recurring_billing_invoice_id;
ALTER TABLE orderitems DROP COLUMN recurring_billing_mode;
