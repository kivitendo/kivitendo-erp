-- @tag: defaults_add_require_transaction_description_sales_quotation
-- @description: Mandantenkonfiguration, um das Setzen der Vorgangsbezeichnug auf Angeboten einzufordern
-- @depends: release_4_1_0

ALTER TABLE defaults ADD COLUMN require_transaction_description_sales_quotation boolean not null DEFAULT false;
