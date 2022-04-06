-- @tag: file_full_texts
-- @description: Tabelle f. Volltext-Suche anlegen
-- @depends: release_3_6_0

CREATE TABLE IF NOT EXISTS file_full_texts (
   id           SERIAL,
   file_id      INTEGER            NOT NULL REFERENCES files(id) ON DELETE CASCADE,
   full_text    TEXT               NOT NULL,
   itime        TIMESTAMP          NOT NULL DEFAULT now(),
   mtime        TIMESTAMP,

   PRIMARY KEY (id)
);

CREATE TRIGGER mtime_file_full_texts BEFORE UPDATE ON file_full_texts FOR EACH ROW EXECUTE PROCEDURE set_mtime();
