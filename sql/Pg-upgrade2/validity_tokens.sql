-- @tag: validity_tokens
-- @description: Gültigkeits-Tokens z.B. für HTML-Formulare
-- @depends: release_3_6_1
CREATE TABLE validity_tokens (
  id          SERIAL,
  scope       TEXT      NOT NULL,
  token       TEXT      NOT NULL,
  itime       TIMESTAMP NOT NULL DEFAULT now(),
  valid_until TIMESTAMP NOT NULL,

  PRIMARY KEY (id),
  UNIQUE (scope, token)
);

INSERT INTO background_jobs (type, package_name, cron_spec, next_run_at, active)
VALUES ('interval', 'ValidityTokenCleanup', '0 3 * * *', now(), true);
