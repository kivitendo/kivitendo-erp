-- @tag: additional_billing_address_ustid_taxnumber
-- @description: Felder für UStId und Steuernummer in zusätzlichen Rechnungsadressen
-- @depends: customer_additional_billing_addresses

ALTER TABLE additional_billing_addresses ADD COLUMN ustid     TEXT,
                                         ADD COLUMN taxnumber TEXT;
