-- @tag: file_version
-- @description: Tabelle für Dokumentenversion
-- @depends: release_3_8_0

CREATE TABLE IF NOT EXISTS file_versions (
   guid          TEXT,
   file_id       INTEGER            NOT NULL REFERENCES files(id) ON DELETE CASCADE,
   version       INTEGER            NOT NULL,
   file_location TEXT               NOT NULL,
   doc_path      TEXT               NOT NULL,
   backend       TEXT               NOT NULL,
   itime         TIMESTAMP          NOT NULL DEFAULT now(),
   mtime         TIMESTAMP,
   PRIMARY KEY (file_id, version)
);

CREATE TRIGGER mtime_file_version BEFORE UPDATE ON file_versions FOR EACH ROW EXECUTE PROCEDURE set_mtime();
