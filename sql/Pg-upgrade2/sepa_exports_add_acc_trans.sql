-- @tag: sepa_exports_add_acc_trans
-- @description: Gutschriften können mit Zahlungen verrechnet werden und lösen Buchungen aus - referentielle Integrität
-- @depends: release_3_9_1
CREATE TABLE sepa_exports_acc_trans (
        sepa_exports_id  INTEGER NOT NULL REFERENCES sepa_export(id),
        acc_trans_id     INTEGER NOT NULL REFERENCES acc_trans(acc_trans_id),
        ar_id            INTEGER          REFERENCES ar(id),
        ap_id            INTEGER          REFERENCES ap(id),
        itime            TIMESTAMP        DEFAULT now(),
        mtime            TIMESTAMP,
        PRIMARY KEY (sepa_exports_id, acc_trans_id, ar_id, ap_id) );

