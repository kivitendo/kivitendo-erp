-- @tag: defaults_customer_vendor_ustid_taxnummer_unique
-- @description: Mandanteneinstellung, ob UStId bzw. Steuernummer eindeutig sein sollen
-- @depends: release_3_5_6_1

ALTER TABLE defaults ADD customer_ustid_taxnummer_unique BOOLEAN DEFAULT FALSE;
ALTER TABLE defaults ADD vendor_ustid_taxnummer_unique   BOOLEAN DEFAULT FALSE;
