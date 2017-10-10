-- @tag: trigram_extension
-- @description: Trigram-Index-Erweiterung installieren
-- @depends: release_3_5_0
-- @ignore: 0
-- @superuser_privileges: 1

CREATE EXTENSION IF NOT EXISTS pg_trgm;
