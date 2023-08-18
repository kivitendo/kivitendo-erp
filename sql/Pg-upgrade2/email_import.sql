-- @tag: email_import
-- @description: Email Journal für importierte E-Mails erweitern
-- @depends: release_3_8_0

CREATE TABLE email_imports (
  id              SERIAL    NOT NULL PRIMARY KEY,
  host_name       TEXT      NOT NULL,
  user_name       TEXT      NOT NULL,
  folder          TEXT      NOT NULL,
  itime           TIMESTAMP NOT NULL DEFAULT now()
);

ALTER TABLE email_journal ADD COLUMN email_import_id INTEGER REFERENCES email_imports(id);
ALTER TABLE email_journal ADD COLUMN folder          TEXT;
ALTER TABLE email_journal ADD COLUMN uid             INTEGER;
CREATE INDEX email_journal_folder_uid_idx ON email_journal (folder, uid);
-- NOTE: change status from text to enum and add 'imported'
CREATE TYPE email_journal_status AS ENUM ('sent', 'send_failed', 'imported');
ALTER TABLE email_journal DROP CONSTRAINT valid_status;
ALTER TABLE email_journal RENAME COLUMN status TO old_status;
ALTER TABLE email_journal ADD COLUMN status email_journal_status;
UPDATE email_journal SET status = 'sent'        WHERE old_status = 'ok';
UPDATE email_journal SET status = 'send_failed' WHERE old_status = 'failed';
ALTER TABLE email_journal ALTER COLUMN status SET NOT NULL;
ALTER TABLE email_journal DROP COLUMN old_status;


