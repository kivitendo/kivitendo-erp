-- @tag: language_add_iso_639_1_language_code
-- @description: ISO 639-1 / ISO 639-2 Sprachcodes, benötigt für PDF-A und ZUGFeRD/Factur-X extended profile Exporte, an Sprachen
-- @depends: release_4_1_0

CREATE TYPE iso_639_1_language_code_enum AS ENUM ('de', 'en');

ALTER TABLE language ADD COLUMN iso_639_1_language_code iso_639_1_language_code_enum;

UPDATE language SET iso_639_1_language_code = 'de' WHERE template_code ~* 'deutsch|german|^de$';
UPDATE language SET iso_639_1_language_code = 'en' WHERE template_code ~* 'englisch|english|^en$';
