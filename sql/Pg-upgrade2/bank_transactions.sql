-- @tag: bank_transactions
-- @description: Erstellen der Tabelle bank_transactions.
-- @depends: release_3_2_0 currencies

CREATE TABLE bank_transactions (
  id SERIAL PRIMARY KEY,
  transaction_id INTEGER,
  remote_bank_code TEXT,
  remote_account_number TEXT,
  transdate DATE NOT NULL,
  valutadate DATE NOT NULL,
  amount numeric(15,5) NOT NULL,
  remote_name TEXT,
  purpose TEXT,
  invoice_amount numeric(15,5) DEFAULT 0,
  local_bank_account_id INTEGER NOT NULL,
  currency_id INTEGER NOT NULL,
  cleared BOOLEAN NOT NULL DEFAULT FALSE,
  itime TIMESTAMP DEFAULT now(),
  FOREIGN KEY (currency_id)            REFERENCES currencies (id),
  FOREIGN KEY (local_bank_account_id)  REFERENCES bank_accounts (id)
);
