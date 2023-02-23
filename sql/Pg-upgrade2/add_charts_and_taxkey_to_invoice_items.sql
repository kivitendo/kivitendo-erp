-- @tag: add_charts_and_tax_to_invoice_items
-- @description: Einkaufsrechnungspositionen mit Steuer und Gegenkonto überlagern
-- @depends: release_3_7_0

ALTER TABLE invoice ADD COLUMN inventory_chart_id INTEGER;
ALTER TABLE invoice ADD FOREIGN KEY (inventory_chart_id) REFERENCES chart(id);
ALTER TABLE invoice ADD COLUMN expense_chart_id INTEGER;
ALTER TABLE invoice ADD FOREIGN KEY (expense_chart_id) REFERENCES chart(id);
ALTER TABLE invoice ADD COLUMN tax_id INTEGER;
ALTER TABLE invoice ADD FOREIGN KEY (tax_id) REFERENCES tax(id);
