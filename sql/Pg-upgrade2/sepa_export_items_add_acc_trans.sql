-- @tag: sepa_export_items_add_acc_trans
-- @description: Gutschriften können mit Zahlungen verrechnet werden und lösen Buchungen aus - referentielle Integrität
-- @depends: release_3_9_1
CREATE TABLE sepa_export_items_acc_trans (
        sepa_export_item_id  INTEGER NOT NULL REFERENCES sepa_export_items(id),
        acc_trans_id         INTEGER NOT NULL REFERENCES acc_trans(acc_trans_id),
        itime                TIMESTAMP      DEFAULT now(),
        mtime                TIMESTAMP,
        PRIMARY KEY (sepa_export_item_id, acc_trans_id) );

ALTER TABLE sepa_export_items  ADD COLUMN vendor_id   INTEGER REFERENCES vendor(id);
ALTER TABLE sepa_export_items  ADD COLUMN customer_id INTEGER REFERENCES customer(id);

