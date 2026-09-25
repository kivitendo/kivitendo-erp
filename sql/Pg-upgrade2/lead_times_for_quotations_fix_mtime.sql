-- @tag: lead_times_for_quotations_mtime_fix
-- @description: Lieferzeiten ähnlich zu Liefer- und Zahlungsbedingungen auf Angeboten angeben
-- @depends: lead_times_for_quotations

ALTER TABLE lead_times ALTER COLUMN mtime set default now();
