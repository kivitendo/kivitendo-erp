-- @tag: oe_purchase_quotation_intake
-- @description: Neuer Einkaufsbeleg: Angebots-Eingang (purchase_quotation_intake)
-- @depends: oe_sales_order_intake_type

ALTER TABLE defaults ADD pqinumber TEXT;
