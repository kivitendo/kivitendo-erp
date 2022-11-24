-- @tag: defaults_record_sender_emails
-- @description: Konfigurierbare E-Mail Absenderadresse je nach Belegtyp
-- @depends: release_3_7_0

ALTER TABLE defaults ADD COLUMN email_sender_sales_quotation TEXT DEFAULT '';
ALTER TABLE defaults ADD COLUMN email_sender_request_quotation TEXT DEFAULT '';
ALTER TABLE defaults ADD COLUMN email_sender_sales_order TEXT DEFAULT '';
ALTER TABLE defaults ADD COLUMN email_sender_purchase_order TEXT DEFAULT '';
ALTER TABLE defaults ADD COLUMN email_sender_invoice TEXT DEFAULT '';
ALTER TABLE defaults ADD COLUMN email_sender_purchase_invoice TEXT DEFAULT '';
ALTER TABLE defaults ADD COLUMN email_sender_letter TEXT DEFAULT '';
ALTER TABLE defaults ADD COLUMN email_sender_purchase_delivery_order TEXT DEFAULT '';
ALTER TABLE defaults ADD COLUMN email_sender_sales_delivery_order TEXT DEFAULT '';
ALTER TABLE defaults ADD COLUMN email_sender_dunning TEXT DEFAULT '';

