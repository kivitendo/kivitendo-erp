-- @tag: email_journal_add_obsolete
-- @description: E-Mail-Journal um obsolete erweitern
-- @depends: release_3_8_0

ALTER TABLE email_journal ADD COLUMN obsolete BOOLEAN NOT NULL DEFAULT FALSE;
