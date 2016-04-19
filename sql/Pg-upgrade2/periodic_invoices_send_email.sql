-- @tag: periodic_invoices_send_email
-- @description: Wiederkehrende Rechnungen automatisch per E-Mail verschicken
-- @depends: release_3_4_0
ALTER TABLE periodic_invoices_configs ADD COLUMN send_email                 BOOLEAN;
ALTER TABLE periodic_invoices_configs ADD COLUMN email_recipient_contact_id INTEGER;
ALTER TABLE periodic_invoices_configs ADD COLUMN email_recipient_address    TEXT;
ALTER TABLE periodic_invoices_configs ADD COLUMN email_sender               TEXT;
ALTER TABLE periodic_invoices_configs ADD COLUMN email_subject              TEXT;
ALTER TABLE periodic_invoices_configs ADD COLUMN email_body                 TEXT;

UPDATE periodic_invoices_configs SET send_email = FALSE;

ALTER TABLE periodic_invoices_configs ALTER COLUMN send_email SET DEFAULT FALSE;
ALTER TABLE periodic_invoices_configs ALTER COLUMN send_email SET NOT NULL;

ALTER TABLE periodic_invoices_configs
ADD FOREIGN KEY (email_recipient_contact_id) REFERENCES contacts (cp_id)
ON DELETE SET NULL;
