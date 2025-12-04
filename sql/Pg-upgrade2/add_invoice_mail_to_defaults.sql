-- @tag: add_invoice_mail_to_defaults
-- @description: Mandantenkonfiguration: Firmen-Rechnungs-E-Mail-Adresse
-- @depends: release_4_0_0
ALTER TABLE defaults
ADD COLUMN invoice_mail TEXT;
