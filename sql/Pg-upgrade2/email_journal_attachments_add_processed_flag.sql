-- @tag: email_journal_attachments_add_processed_flag
-- @description: E-Mailanhänge als verarbeitet markieren
-- @depends: release_3_8_0
ALTER TABLE email_journal_attachments ADD COLUMN processed BOOLEAN DEFAULT FALSE NOT NULL;

-- set attachments of send emails to processed
UPDATE email_journal_attachments
SET processed = TRUE
FROM email_journal
WHERE email_journal_id = email_journal.id AND email_journal.status != 'imported'
