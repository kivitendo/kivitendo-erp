-- @tag: part_customer_prices_add_description
-- @description: Kundenspezifischen Preisen Beschreibung und Bemerkungen/Langtext hinzufügen
-- @depends: create_part_customerprices

ALTER TABLE part_customer_prices ADD COLUMN part_description     TEXT;
ALTER TABLE part_customer_prices ADD COLUMN part_longdescription TEXT;
