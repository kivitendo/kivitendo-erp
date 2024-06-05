-- @tag: variant_property_unique_values
-- @description: Ausprägungen für Eigenschaft eindeutig machen
-- @depends: add_variants
-- @ignore: 0

ALTER TABLE variant_property_values ADD CONSTRAINT variant_property_unique_values
  UNIQUE(variant_property_id, value);
