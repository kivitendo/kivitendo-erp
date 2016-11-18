-- @tag: sepa_reference_add_vc_vc_id
-- @description: Einstellung, ob bei SEPA Überweisungen zusätzlich die Lieferanten-/Kundennummer im Verwendungszweck angezeigt wird
-- @depends: release_3_4_1

ALTER TABLE defaults ADD COLUMN sepa_reference_add_vc_vc_id boolean DEFAULT FALSE;
