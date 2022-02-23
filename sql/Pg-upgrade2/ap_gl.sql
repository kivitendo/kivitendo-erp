-- @tag: ap_gl
-- @description: Hilfstabelle für automatische GL-Buchung nach Kreditorenbuchung
-- @depends: release_3_5_0
-- @ignore: 0
      CREATE TABLE ap_gl (
        ap_id                   integer,
        gl_id                   integer,
        itime                   TIMESTAMP      DEFAULT now(),
        mtime                   TIMESTAMP,
        PRIMARY KEY (ap_id, gl_id),
        FOREIGN KEY (ap_id)                    REFERENCES ap (id),
        FOREIGN KEY (gl_id)                    REFERENCES gl (id) ON DELETE CASCADE);




