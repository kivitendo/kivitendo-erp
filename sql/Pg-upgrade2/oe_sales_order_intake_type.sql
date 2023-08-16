-- @tag: oe_sales_order_intake_type
-- @description: Neuer Auftragsbeleg: Auftrags-Eingang (sales_order_intake)
-- @depends: release_3_6_0

ALTER TABLE oe ADD COLUMN intake BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE defaults ADD soinumber TEXT;
