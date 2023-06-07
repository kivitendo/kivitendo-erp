-- @tag: defaults_add_email_server_configs
-- @description: Email-Server-Konfigurationen pro Mandant
-- @depends: release_3_8_0

ALTER TABLE defaults ADD COLUMN mail_delivery_host     TEXT NOT NULL DEFAULT '';
ALTER TABLE defaults ADD COLUMN mail_delivery_security TEXT NOT NULL DEFAULT 'tls';
ALTER TABLE defaults ADD COLUMN mail_delivery_port     INTEGER NOT NULL DEFAULT 25;
ALTER TABLE defaults ADD COLUMN mail_delivery_login    TEXT NOT NULL DEFAULT '';
ALTER TABLE defaults ADD COLUMN mail_delivery_password TEXT NOT NULL DEFAULT '';

ALTER TABLE defaults ADD COLUMN imap_client_enabled     boolean NOT NULL DEFAULT FALSE;
ALTER TABLE defaults ADD COLUMN imap_client_ssl         boolean NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN imap_client_base_folder TEXT NOT NULL DEFAULT 'INBOX';
ALTER TABLE defaults ADD COLUMN imap_client_hostname    TEXT NOT NULL DEFAULT '';
ALTER TABLE defaults ADD COLUMN imap_client_port        INTEGER NOT NULL DEFAULT 993;
ALTER TABLE defaults ADD COLUMN imap_client_username    TEXT NOT NULL DEFAULT '';
ALTER TABLE defaults ADD COLUMN imap_client_password    TEXT NOT NULL DEFAULT '';

ALTER TABLE defaults ADD COLUMN sent_emails_in_imap_enabled  boolean NOT NULL DEFAULT FALSE;
ALTER TABLE defaults ADD COLUMN sent_emails_in_imap_ssl      boolean NOT NULL DEFAULT TRUE;
ALTER TABLE defaults ADD COLUMN sent_emails_in_imap_folder   TEXT NOT NULL DEFAULT 'Sent';
ALTER TABLE defaults ADD COLUMN sent_emails_in_imap_hostname TEXT NOT NULL DEFAULT '';
ALTER TABLE defaults ADD COLUMN sent_emails_in_imap_port     INTEGER NOT NULL DEFAULT 993;
ALTER TABLE defaults ADD COLUMN sent_emails_in_imap_username TEXT NOT NULL DEFAULT '';
ALTER TABLE defaults ADD COLUMN sent_emails_in_imap_password TEXT NOT NULL DEFAULT '';
