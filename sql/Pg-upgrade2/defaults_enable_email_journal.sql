-- @tag: defaults_enable_email_journal
-- @description: Email Journal konfigurierbar machen
-- @depends: email_journal

ALTER TABLE defaults ADD COLUMN  email_journal integer DEFAULT 2;
UPDATE defaults SET email_journal = 2;
