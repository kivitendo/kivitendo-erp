-- @tag: change_variant_properties_abbreviation_to_text
-- @description: Freitext bei Abkürzung von Varianteneigenschaften und Ausprägungen zulassen
-- @depends: add_variants
-- @ignore: 0

ALTER TABLE variant_properties      ALTER COLUMN abbreviation TYPE text;
ALTER TABLE variant_property_values ALTER COLUMN abbreviation TYPE text;
