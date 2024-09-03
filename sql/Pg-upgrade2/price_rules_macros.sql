-- @tag: price_rules_macros
-- @description:  Struktur für Preisregel Makros
-- @depends: release_3_9_0 price_rules

CREATE TABLE price_rule_macros (
  id               SERIAL PRIMARY KEY,
  name             TEXT NOT NULL,
  type             TEXT NOT NULL,
  priority         INTEGER NOT NULL DEFAULT 3,
  obsolete         BOOLEAN NOT NULL DEFAULT FALSE,
  json_definition  JSON NOT NULL,
  itime            TIMESTAMP,
  mtime            TIMESTAMP
);

ALTER TABLE price_rules ADD COLUMN price_rule_macro_id INTEGER REFERENCES price_rule_macros(id);
