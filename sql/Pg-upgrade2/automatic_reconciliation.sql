-- @tag: automatic_reconciliation
-- @description: Erstellt Tabelle reconiliation_links für den automatischen Kontenabgleich.
-- @depends: release_3_2_0 bank_transactions

CREATE TABLE reconciliation_links (
  id                      integer NOT NULL DEFAULT nextval('id'),
  bank_transaction_id     integer NOT NULL,
  acc_trans_id            bigint  NOT NULL,
  rec_group               integer NOT NULL,

  PRIMARY KEY (id),
  FOREIGN KEY (bank_transaction_id)      REFERENCES bank_transactions (id),
  FOREIGN KEY (acc_trans_id)             REFERENCES acc_trans (acc_trans_id)
);
