-- @tag: recorditem_totals
-- @description: Zeilesummen in Belegen speichern
-- @depends: release_3_9_2

ALTER TABLE orderitems ADD COLUMN linetotal numeric(15,5);
ALTER TABLE orderitems ADD COLUMN linetotal_cost numeric(15,5);
ALTER TABLE orderitems ADD COLUMN sellprice_taxable numeric(15,5);
ALTER TABLE orderitems ADD COLUMN net_amount numeric(15,5);
ALTER TABLE orderitems ADD COLUMN tax_amount numeric(15,5);
ALTER TABLE orderitems ADD COLUMN taxkey_id numeric(15,5);

ALTER TABLE delivery_order_items ADD COLUMN linetotal numeric(15,5);
ALTER TABLE delivery_order_items ADD COLUMN linetotal_cost numeric(15,5);
ALTER TABLE delivery_order_items ADD COLUMN sellprice_taxable numeric(15,5);
ALTER TABLE delivery_order_items ADD COLUMN net_amount numeric(15,5);
ALTER TABLE delivery_order_items ADD COLUMN tax_amount numeric(15,5);
ALTER TABLE delivery_order_items ADD COLUMN taxkey_id numeric(15,5);

ALTER TABLE invoice ADD COLUMN linetotal numeric(15,5);
ALTER TABLE invoice ADD COLUMN linetotal_cost numeric(15,5);
ALTER TABLE invoice ADD COLUMN sellprice_taxable numeric(15,5);
ALTER TABLE invoice ADD COLUMN net_amount numeric(15,5);
ALTER TABLE invoice ADD COLUMN tax_amount numeric(15,5);
ALTER TABLE invoice ADD COLUMN taxkey_id numeric(15,5);

ALTER TABLE reclamation_items ADD COLUMN linetotal numeric(15,5);
ALTER TABLE reclamation_items ADD COLUMN linetotal_cost numeric(15,5);
ALTER TABLE reclamation_items ADD COLUMN sellprice_taxable numeric(15,5);
ALTER TABLE reclamation_items ADD COLUMN net_amount numeric(15,5);
ALTER TABLE reclamation_items ADD COLUMN tax_amount numeric(15,5);
ALTER TABLE reclamation_items ADD COLUMN taxkey_id numeric(15,5);
