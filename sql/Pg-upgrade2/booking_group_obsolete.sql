-- @tag: booking_group_obsolete
-- @description: Buchungsgruppen ungültig setzen können
-- @depends: release_3_7_0
ALTER TABLE buchungsgruppen
ADD COLUMN obsolete BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE parts
SET obsolete = FALSE
WHERE obsolete IS NULL;

ALTER TABLE parts
ALTER COLUMN obsolete SET NOT NULL;
