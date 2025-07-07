-- @tag: secrets
-- @description: Tabelle für verschlüsselte Secrets
-- @depends: release_3_9_2
CREATE TABLE secrets (
  id SERIAL PRIMARY KEY,

  tag text NOT NULL UNIQUE,
  description TEXT,
  cipher BYTEA,
  iv BYTEA,
  salt TEXT,
  utf_flag BOOLEAN NOT NULL
);
