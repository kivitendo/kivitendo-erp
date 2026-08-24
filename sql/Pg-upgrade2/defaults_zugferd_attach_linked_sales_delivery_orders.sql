-- @tag: defaults_zugferd_attach_linked_sales_delivery_orders
-- @description: Mandantenkonfig: Lieferscheine an ZUGFeRD anhängen
-- @depends: release_4_1_0

CREATE TYPE zugferd_attach_linked_sales_delivery_orders_type AS ENUM (
       'no',
       'only_if_exists',
       'yes',
       'create_always'
);

ALTER TABLE defaults ADD COLUMN zugferd_attach_linked_sales_delivery_orders zugferd_attach_linked_sales_delivery_orders_type NOT NULL DEFAULT 'no';
