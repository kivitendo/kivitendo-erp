-- @tag: ar_add_qr_unstructured_message
-- @description: Spalte für unstrukturierte Mitteilung bei schweizer QR-Rechnung hinzufügen
-- @depends: release_3_7_0
ALTER TABLE ar ADD COLUMN qr_unstructured_message text;
