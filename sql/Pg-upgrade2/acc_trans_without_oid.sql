-- @tag: acc_trans_without_oid
-- @description: Einführen einer ID-Spalte in acc_trans
-- @depends: release_2_4_3 cb_ob_transaction

-- INFO: Dieses Script hat früher die Spalte acc_trans_id aus der
-- impliziten OID gesetzt. PostgreSQL 12 unterstützt aber keine OIDs
-- mehr, daher wurde die OID hier entfernt. Das ist insofern auch kein
-- Problem, weil dieses Upgrade-Script in Version 2.6.0 benutzt wurde,
-- und direkte Updates auf die aktuelle kivitendo-Version von vor 3.0
-- eh nicht mehr unterstützt werden.
--
-- Das Script muss aber trotzdem beim Anlegen neuer Datenbanken
-- abgearbeitet werden und daher funktionieren.

CREATE SEQUENCE acc_trans_id_seq;

CREATE TABLE new_acc_trans (
    acc_trans_id bigint DEFAULT nextval('acc_trans_id_seq'),
    trans_id integer,
    chart_id integer,
    amount numeric(15,5),
    transdate date DEFAULT date('now'::text),
    gldate date DEFAULT date('now'::text),
    source text,
    cleared boolean DEFAULT false,
    fx_transaction boolean DEFAULT false,
    ob_transaction boolean DEFAULT false,
    cb_transaction boolean DEFAULT false,
    project_id integer,
    memo text,
    taxkey integer,
    itime timestamp without time zone DEFAULT now(),
    mtime timestamp without time zone
);

INSERT INTO new_acc_trans (trans_id, chart_id, amount, transdate, gldate, source, cleared,
                           fx_transaction, ob_transaction, cb_transaction, project_id, memo, taxkey, itime, mtime)
  SELECT trans_id, chart_id, amount, transdate, gldate, source, cleared,
    fx_transaction, ob_transaction, cb_transaction, project_id, memo, taxkey, itime, mtime
  FROM acc_trans;

DROP TABLE acc_trans;
ALTER TABLE new_acc_trans RENAME TO acc_trans;

CREATE INDEX acc_trans_trans_id_key ON acc_trans USING btree (trans_id);
CREATE INDEX acc_trans_chart_id_key ON acc_trans USING btree (chart_id);
CREATE INDEX acc_trans_transdate_key ON acc_trans USING btree (transdate);
CREATE INDEX acc_trans_source_key ON acc_trans USING btree (lower(source));

ALTER TABLE ONLY acc_trans
    ADD CONSTRAINT "$1" FOREIGN KEY (chart_id) REFERENCES chart(id);

CREATE TRIGGER mtime_acc_trans
    BEFORE UPDATE ON acc_trans
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();
