-- @tag: defaults_bcc_to_login
-- @description: BCC Email zu aktuellem Benutzer
-- @depends: defaults_global_bcc

ALTER TABLE defaults ADD bcc_to_login boolean NOT NULL DEFAULT FALSE;

