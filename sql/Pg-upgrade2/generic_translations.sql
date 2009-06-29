-- @tag: generic_translations
-- @description: Allgemeine Tabelle fuer Uebersetzungen
-- @depends: release_2_6_0
CREATE TABLE generic_translations (
  id SERIAL,
  language_id integer,
  translation_type varchar(100) NOT NULL,
  translation_id integer,
  translation text,

  PRIMARY KEY (id),
  FOREIGN KEY (language_id) REFERENCES language (id)
);
CREATE INDEX generic_translations_type_id_idx ON generic_translations (language_id, translation_type, translation_id);

