-- @tag: email_oauth2
-- @description: OAuth2 E-Mail
-- @depends: release_3_9_1

-- Note: sender_id may be NULL to indicate a mail sent by the system
-- without a user being logged in – e.g. by the task server.
CREATE TABLE oauth_token (
  id              SERIAL    NOT NULL,
  registration    TEXT      NOT NULL,
  authflow        TEXT      NOT NULL,
  email           TEXT      NOT NULL,
  access_token_expiration TIMESTAMP NOT NULL,
  access_token    TEXT      NOT NULL,
  refresh_token   TEXT      NOT NULL,
  itime           TIMESTAMP NOT NULL DEFAULT now(),
  mtime           TIMESTAMP NOT NULL DEFAULT now(),

  PRIMARY KEY (id),
  CONSTRAINT valid_registration CHECK (registration IN ('google', 'microsoft'))
);

CREATE TRIGGER mtime_oauth_token             BEFORE UPDATE ON oauth_token             FOR EACH ROW EXECUTE PROCEDURE set_mtime();
