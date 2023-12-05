-- @tag: variants_add_column_sortkey
-- @description: Sortierung für Varianteneigenschaften
-- @depends: add_variants
-- @ignore: 0

ALTER TABLE variant_properties ADD COLUMN sortkey INTEGER;
