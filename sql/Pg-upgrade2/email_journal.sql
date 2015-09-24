-- @tag: email_journal
-- @description: Journal für verschickte E-Mails
-- @depends: release_3_3_0

-- Note: sender_id may be NULL to indicate a mail sent by the system
-- without a user being logged in – e.g. by the task server.
CREATE TABLE email_journal (
  id              SERIAL    NOT NULL,
  sender_id       INTEGER,
  "from"          TEXT      NOT NULL,
  recipients      TEXT      NOT NULL,
  sent_on         TIMESTAMP NOT NULL DEFAULT now(),
  subject         TEXT      NOT NULL,
  body            TEXT      NOT NULL,
  headers         TEXT      NOT NULL,
  status          TEXT      NOT NULL,
  extended_status TEXT      NOT NULL,
  itime           TIMESTAMP NOT NULL DEFAULT now(),
  mtime           TIMESTAMP NOT NULL DEFAULT now(),

  PRIMARY KEY (id),
  FOREIGN KEY (sender_id) REFERENCES employee (id),
  CONSTRAINT valid_status CHECK (status IN ('ok', 'failed'))
);

CREATE TABLE email_journal_attachments (
  id               SERIAL    NOT NULL,
  position         INTEGER   NOT NULL,
  email_journal_id INTEGER   NOT NULL,
  name             TEXT      NOT NULL,
  mime_type        TEXT      NOT NULL,
  content          BYTEA     NOT NULL,
  itime            TIMESTAMP NOT NULL DEFAULT now(),
  mtime            TIMESTAMP NOT NULL DEFAULT now(),

  PRIMARY KEY (id),
  FOREIGN KEY (email_journal_id) REFERENCES email_journal (id) ON DELETE CASCADE
);

CREATE TRIGGER mtime_email_journal             BEFORE UPDATE ON email_journal             FOR EACH ROW EXECUTE PROCEDURE set_mtime();
CREATE TRIGGER mtime_email_journal_attachments BEFORE UPDATE ON email_journal_attachments FOR EACH ROW EXECUTE PROCEDURE set_mtime();
