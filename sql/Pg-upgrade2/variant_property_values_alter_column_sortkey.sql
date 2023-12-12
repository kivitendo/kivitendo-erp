-- @tag: variant_values_alter_column_sortkey
-- @description: sortkey für Varianteneigenschaftswert darf NULL sein
-- @depends: add_variants
-- @ignore: 0

ALTER TABLE variant_property_values ALTER COLUMN sortkey DROP NOT NULL;
