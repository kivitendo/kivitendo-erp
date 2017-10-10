-- @tag: user_preferences
-- @description: Benutzereinstellungen
-- @depends: release_3_4_1

CREATE TABLE user_preferences (
  id         SERIAL PRIMARY KEY,
  login      TEXT NOT NULL,
  namespace  TEXT NOT NULL,
  version    NUMERIC(15,5),
  key        TEXT NOT NULL,
  value      TEXT,
  UNIQUE (login, namespace, version, key)
);
