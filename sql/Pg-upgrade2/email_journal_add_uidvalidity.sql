-- @tag: email_journal_add_uidvalidity
-- @description: Ordner uidvalidity für importierte E-Mails
-- @depends: release_3_8_0

ALTER TABLE email_journal ADD COLUMN folder_uidvalidity TEXT;
