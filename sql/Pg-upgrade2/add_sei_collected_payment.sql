-- @tag: add_sei_collected_payment
-- @description: Spalten für Sammelüberweisung in SEI
-- @depends: release_3_9_1

ALTER TABLE sepa_export_items ADD COLUMN collected_payment boolean DEFAULT FALSE;
ALTER TABLE sepa_export_items ADD COLUMN is_combined_payment boolean DEFAULT FALSE;

