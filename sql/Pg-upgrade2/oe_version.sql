-- @tag: oe_version
-- @description: Hilfstabelle für Versionierungen von Angeboten und Aufträgen
-- @depends: release_3_6_0
-- @ignore: 0
      CREATE TABLE oe_version (
        oe_id                   integer,
        version                 INTEGER NOT NULL,
        final_version           BOOLEAN DEFAULT FALSE,
        email_journal_id        integer,
        file_id                 integer,
        itime                   TIMESTAMP      DEFAULT now(),
        mtime                   TIMESTAMP,
        PRIMARY KEY (oe_id, version),
        FOREIGN KEY (oe_id)                    REFERENCES oe (id),
        FOREIGN KEY (email_journal_id)         REFERENCES email_journal (id),
        FOREIGN KEY (file_id)                  REFERENCES files (id));

CREATE TRIGGER mtime_oe_version BEFORE UPDATE ON oe_version FOR EACH ROW EXECUTE PROCEDURE set_mtime();
