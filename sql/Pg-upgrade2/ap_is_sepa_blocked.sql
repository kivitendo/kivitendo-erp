-- @tag: ap_is_sepa_blocked
-- @description: Flag, ob Überweisungen per SEPA gesperrt sind
-- @depends: release_3_7_0

ALTER TABLE ap ADD COLUMN is_sepa_blocked BOOLEAN DEFAULT FALSE;
