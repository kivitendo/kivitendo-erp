-- @tag: email_journal_extend_status
-- @description: Zusätzlicher Status für E-Mail-Journal
-- @depends: release_3_8_0 email_import email_journal_add_uidvalidity

ALTER TYPE email_journal_status ADD VALUE 'record_imported' AFTER 'imported';
