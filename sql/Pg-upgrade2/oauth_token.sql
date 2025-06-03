-- @tag: oauth2_tokens
-- @description: Tabelle für OAuth2 Tokens
-- @depends: release_3_9_2

CREATE TABLE oauth_token (
  id                      SERIAL PRIMARY KEY,
  registration            TEXT NOT NULL,
  authflow                TEXT NOT NULL,
  email                   TEXT,
  tokenstate              TEXT,
  redirect_uri            TEXT,
  verifier                TEXT,
  client_id               TEXT NOT NULL,
  client_secret           TEXT NOT NULL,
  scope                   TEXT NOT NULL,
  access_token            TEXT,
  refresh_token           TEXT,
  access_token_expiration TIMESTAMP,
  itime                   TIMESTAMP DEFAULT now() NOT NULL,
  mtime                   TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TRIGGER mtime_oauth_token BEFORE UPDATE ON oauth_token FOR EACH ROW EXECUTE PROCEDURE set_mtime();
