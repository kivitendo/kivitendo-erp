-- @tag: bank_accounts
-- @description: Tabelle für Bankkonten (u.a. für SEPA-Export)
-- @depends: release_2_4_3
CREATE TABLE bank_accounts (
  id integer NOT NULL DEFAULT nextval('id'),
  account_number varchar(100),
  bank_code varchar(100),
  iban varchar(100),
  bic varchar(100),
  bank text,
  chart_id integer NOT NULL,

  PRIMARY KEY (id),
  FOREIGN KEY (chart_id) REFERENCES chart (id)
);

ALTER TABLE customer ADD COLUMN iban varchar(100);
ALTER TABLE customer ADD COLUMN bic varchar(100);
UPDATE customer SET iban = '', bic = '';

ALTER TABLE vendor ADD COLUMN iban varchar(100);
ALTER TABLE vendor ADD COLUMN bic varchar(100);
UPDATE vendor SET iban = '', bic = '';
