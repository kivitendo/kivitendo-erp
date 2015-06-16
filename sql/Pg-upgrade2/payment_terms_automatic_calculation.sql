-- @tag: payment_terms_automatic_calculation
-- @description: Zahlungsbedingungen: Einstellmöglichkeit zur automatischen/manuellen Datumsberechnung
-- @depends: release_3_2_0

ALTER TABLE payment_terms ADD COLUMN auto_calculation BOOLEAN;
UPDATE payment_terms SET auto_calculation = TRUE;
ALTER TABLE payment_terms ALTER COLUMN auto_calculation SET NOT NULL;
