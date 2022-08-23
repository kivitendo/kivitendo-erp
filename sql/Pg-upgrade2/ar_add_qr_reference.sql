-- @tag: ar_add_qr_reference
-- @description: Spalte für QR-Referenz
-- @depends: release_3_6_1
ALTER TABLE ar ADD COLUMN qr_reference text;
