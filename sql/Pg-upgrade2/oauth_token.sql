-- @tag: oauth2_tokens
-- @description: Tabelle für OAuth2 Tokens
-- @depends: release_3_9_2

CREATE TABLE oauth_token (
  id                      SERIAL PRIMARY KEY,
  registration            TEXT NOT NULL,
  employee_id             INT REFERENCES employee(id),
  email                   TEXT,
  scope                   TEXT,
  tokenstate              TEXT,
  verifier                TEXT,
  access_token            TEXT,
  refresh_token           TEXT,
  access_token_expiration TIMESTAMP,
  itime                   TIMESTAMP DEFAULT now() NOT NULL,
  mtime                   TIMESTAMP DEFAULT now() NOT NULL
);

CREATE TRIGGER mtime_oauth_token BEFORE UPDATE ON oauth_token FOR EACH ROW EXECUTE PROCEDURE set_mtime();
