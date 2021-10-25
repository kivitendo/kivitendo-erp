-- @tag: customer_additional_billing_addresses
-- @description: Kundenstammdaten: zusätzliche Rechnungsadressen
-- @depends: release_3_5_8
CREATE TABLE additional_billing_addresses (
  id              SERIAL,
  customer_id     INTEGER,
  name            TEXT,
  department_1    TEXT,
  department_2    TEXT,
  contact         TEXT,
  street          TEXT,
  zipcode         TEXT,
  city            TEXT,
  country         TEXT,
  gln             TEXT,
  email           TEXT,
  phone           TEXT,
  fax             TEXT,
  default_address BOOLEAN NOT NULL DEFAULT FALSE,

  itime           TIMESTAMP NOT NULL DEFAULT now(),
  mtime           TIMESTAMP NOT NULL DEFAULT now(),

  PRIMARY KEY (id),
  FOREIGN KEY (customer_id) REFERENCES customer (id)
);

CREATE TRIGGER mtime_additional_billing_addresses
BEFORE UPDATE ON additional_billing_addresses
FOR EACH ROW EXECUTE PROCEDURE set_mtime();

ALTER TABLE oe
  ADD COLUMN billing_address_id INTEGER,
  ADD FOREIGN KEY (billing_address_id)
    REFERENCES additional_billing_addresses (id);

ALTER TABLE delivery_orders
  ADD COLUMN billing_address_id INTEGER,
  ADD FOREIGN KEY (billing_address_id)
    REFERENCES additional_billing_addresses (id);

ALTER TABLE ar
  ADD COLUMN billing_address_id INTEGER,
  ADD FOREIGN KEY (billing_address_id)
    REFERENCES additional_billing_addresses (id);
