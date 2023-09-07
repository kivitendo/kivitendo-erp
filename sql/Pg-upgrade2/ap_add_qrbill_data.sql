-- @tag: ap_add_qrbill_data
-- @description: Spalte für QR-Rechnungsdaten hinzufügen (Schweiz)
-- @depends: release_3_7_0
ALTER TABLE ap ADD COLUMN qrbill_data text;
