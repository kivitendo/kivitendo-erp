-- @tag: add_variants
-- @description: Neue Tabllen für Variantenartikel
-- @depends: release_3_8_0
-- @ignore: 0

ALTER TYPE part_type_enum ADD VALUE 'parent_variant';
ALTER TYPE part_type_enum ADD VALUE 'variant';

ALTER TABLE defaults ADD parent_variant_number TEXT;
ALTER TABLE defaults ADD variant_number TEXT;

CREATE TABLE parts_parent_variant_id_parts_variant_id (
  parent_variant_id INTEGER NOT NULL        REFERENCES parts(id),
  variant_id        INTEGER NOT NULL UNIQUE REFERENCES parts(id),
  PRIMARY KEY (parent_variant_id, variant_id)
);

CREATE TABLE variant_properties (
  id           SERIAL PRIMARY KEY,
  name         TEXT       NOT NULL,
  unique_name  TEXT       NOT NULL UNIQUE,
  abbreviation VARCHAR(4) NOT NULL,
  itime        TIMESTAMP DEFAULT now(),
  mtime        TIMESTAMP
);
CREATE TRIGGER mtime_variant_properties
  BEFORE UPDATE ON variant_properties
  FOR EACH ROW EXECUTE PROCEDURE set_mtime();

CREATE TABLE variant_properties_parts (
  variant_property_id INTEGER NOT NULL REFERENCES variant_properties(id),
  part_id             INTEGER NOT NULL REFERENCES parts(id),
  PRIMARY KEY (part_id, variant_property_id)
);

CREATE TABLE translation_variant_properties (
  variant_property_id INTEGER NOT NULL REFERENCES variant_properties(id),
  language_id         INTEGER NOT NULL REFERENCES language(id),
  name                TEXT    NOT NULL,
  itime               TIMESTAMP DEFAULT now(),
  mtime               TIMESTAMP,
  PRIMARY KEY (variant_property_id, language_id)
);
CREATE TRIGGER mtime_translation_variant_properties
  BEFORE UPDATE ON translation_variant_properties
  FOR EACH ROW EXECUTE PROCEDURE set_mtime();

CREATE TABLE variant_property_values (
  id                  SERIAL PRIMARY KEY,
  variant_property_id INTEGER NOT NULL REFERENCES variant_properties(id),
  value               TEXT    NOT NULL,
  abbreviation        VARCHAR(4) NOT NULL,
  sortkey             INTEGER NOT NULL,
  itime               TIMESTAMP DEFAULT now(),
  mtime               TIMESTAMP
);
CREATE TRIGGER mtime_variant_property_values
  BEFORE UPDATE ON variant_property_values
  FOR EACH ROW EXECUTE PROCEDURE set_mtime();

CREATE TABLE variant_property_values_parts (
  variant_property_value_id INTEGER NOT NULL REFERENCES variant_property_values(id),
  part_id                   INTEGER NOT NULL REFERENCES parts(id),
  PRIMARY KEY (part_id, variant_property_value_id)
);

CREATE TABLE translation_variant_property_values (
  variant_property_value_id INTEGER NOT NULL REFERENCES variant_property_values(id),
  language_id               INTEGER NOT NULL REFERENCES language(id),
  value                     TEXT    NOT NULL,
  itime                     TIMESTAMP DEFAULT now(),
  mtime                     TIMESTAMP,
  PRIMARY KEY (variant_property_value_id, language_id)
);
CREATE TRIGGER mtime_translation_variant_property_values
  BEFORE UPDATE ON translation_variant_property_values
  FOR EACH ROW EXECUTE PROCEDURE set_mtime();
