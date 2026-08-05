-- @tag: file_versions_zugferd_options
-- @description: Tabelle für ZUGFeRD-Einstellungen für Dokumentenversionen
-- @depends: file_version file_versions_guid_as_primary_key

CREATE TABLE file_versions_zugferd_options (
   id         SERIAL PRIMARY KEY,
   guid       TEXT      NOT NULL UNIQUE REFERENCES file_versions(guid) ON DELETE CASCADE,
   attach     BOOLEAN   NOT NULL DEFAULT FALSE,
   doc_id     TEXT,
   doc_name   TEXT,
   itime      TIMESTAMP NOT NULL DEFAULT now(),
   mtime      TIMESTAMP
);

CREATE TRIGGER mtime_file_versions_zugferd_options BEFORE UPDATE ON file_versions_zugferd_options FOR EACH ROW EXECUTE PROCEDURE set_mtime();
