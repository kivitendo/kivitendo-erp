-- @tag: countries_language
-- @description: Lokalisierte Übersetzungen der Ländernamen
-- @depends: release_4_1_0

CREATE TABLE countries_language (
  id             SERIAL PRIMARY KEY,
  country_id     INTEGER NOT NULL references countries (id),
  language_id    INTEGER NOT NULL references language (id) ON DELETE CASCADE,
  localized      TEXT NOT NULL default ''
);

CREATE UNIQUE INDEX ON countries_language (country_id, language_id);
