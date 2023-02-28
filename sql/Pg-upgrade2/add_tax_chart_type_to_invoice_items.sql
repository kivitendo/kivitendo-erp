-- @tag: add_tax_chart_type_to_invoice_items
-- @description: Auswahl von Warenbuchungsmethode pro Einkaufrechnungszeile
-- @depends: release_3_7_0

ALTER TABLE invoice ADD COLUMN tax_chart_type VARCHAR(20);
