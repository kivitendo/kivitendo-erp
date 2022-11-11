-- @tag: customer_add_dunning_mail
-- @description: Mahnungsadresse (E-Mail-Empfänger)
-- @depends: release_3_6_0
ALTER TABLE customer ADD COLUMN dunning_mail text;
ALTER TABLE additional_billing_addresses ADD COLUMN dunning_mail text;
