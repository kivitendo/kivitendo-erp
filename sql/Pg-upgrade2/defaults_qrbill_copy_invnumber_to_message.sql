-- @tag: defaults_qrbill_copy_invnumber_to_message
-- @description: Schweizer QR-Rechnung Option Rechnungsnummer in Mitteilung kopieren
-- @depends: release_3_7_0
ALTER TABLE defaults ADD COLUMN qrbill_copy_invnumber boolean DEFAULT false;