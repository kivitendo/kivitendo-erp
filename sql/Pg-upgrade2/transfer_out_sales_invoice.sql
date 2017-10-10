-- @tag: transfer_out_sales_invoice
-- @description: Felder für das Feature "Auslagern beim Buchen von Verkaufsrechnungen".
-- @depends: warehouse_add_delivery_order_items_stock_id

ALTER TABLE inventory ADD COLUMN invoice_id      INTEGER REFERENCES invoice(id);
ALTER TABLE defaults  ADD COLUMN is_transfer_out BOOLEAN NOT NULL DEFAULT FALSE;
