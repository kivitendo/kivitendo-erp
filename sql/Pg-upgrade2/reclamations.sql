-- @tag: reclamations
-- @description: Add reclamations, reclamation_items and reclamation_reasons
-- @depends: release_3_5_7
-- @ignore: 0

CREATE TABLE reclamation_reasons (
  id                       SERIAL                      PRIMARY KEY,
  name                     TEXT                        NOT NULL,
  description              TEXT                        NOT NULL,
  position                 INTEGER                     NOT NULL,
  itime                    TIMESTAMP without time zone DEFAULT now(),
  mtime                    TIMESTAMP without time zone,
  valid_for_sales          BOOLEAN                     NOT NULL DEFAULT false,
  valid_for_purchase       BOOLEAN                     NOT NULL DEFAULT false
);
CREATE TRIGGER mtime_reclamation_reasons
  BEFORE UPDATE ON reclamation_reasons
  FOR EACH ROW EXECUTE PROCEDURE set_mtime();

CREATE TABLE reclamations (
--basic
  id                      INTEGER                     NOT NULL DEFAULT nextval('id'),
  record_number           TEXT                        NOT NULL,
  transdate               DATE                        DEFAULT now(),
  itime                   TIMESTAMP without time zone DEFAULT now(),
  mtime                   TIMESTAMP without time zone,
  delivered               BOOLEAN                     NOT NULL DEFAULT false,
  closed                  BOOLEAN                     NOT NULL DEFAULT false,
--header
  employee_id             INTEGER                     NOT NULL REFERENCES employee(id),
  globalproject_id        INTEGER                     REFERENCES project(id),
  delivery_term_id        INTEGER                     REFERENCES delivery_terms(id),
  shipto_id               INTEGER                     REFERENCES shipto(shipto_id),
  department_id           INTEGER                     REFERENCES department(id),
  contact_id              INTEGER                     REFERENCES contacts(cp_id),
  shipvia                 TEXT,
  transaction_description TEXT,
  shippingpoint           TEXT,
  cv_record_number        TEXT,
  reqdate                 DATE,
--money/summery
  amount                  NUMERIC(15,5),
  netamount               NUMERIC(15,5),
  payment_id              INTEGER                     REFERENCES payment_terms(id),
  currency_id             INTEGER                     NOT NULL REFERENCES currencies(id),
  taxincluded             BOOLEAN                     NOT NULL,
  tax_point               DATE,
  exchangerate            NUMERIC(15,5),
  taxzone_id              INTEGER                     NOT NULL REFERENCES tax_zones(id),
--other
  notes                   TEXT,
  intnotes                TEXT,
  language_id             INTEGER                     REFERENCES language(id),

  salesman_id             INTEGER                     REFERENCES employee(id),
  customer_id             INTEGER                     REFERENCES customer(id),

  vendor_id               INTEGER                     REFERENCES vendor(id),

  CONSTRAINT reclamations_customervendor_check CHECK (
       (customer_id IS NOT NULL AND vendor_id   IS NULL)
    OR (vendor_id   IS NOT NULL AND customer_id IS NULL)
  ),

  PRIMARY KEY (id)
);
CREATE TRIGGER mtime_reclamations BEFORE UPDATE ON reclamations FOR EACH ROW EXECUTE PROCEDURE set_mtime();

ALTER TABLE defaults ADD COLUMN p_reclamation_record_number TEXT NOT NULL DEFAULT 0;
ALTER TABLE defaults ADD COLUMN s_reclamation_record_number TEXT NOT NULL DEFAULT 0;

CREATE TABLE reclamation_items (
--base
  id                         SERIAL                      PRIMARY KEY,
  reclamation_id             INTEGER                     NOT NULL REFERENCES reclamations(id) ON DELETE CASCADE,
  reason_id                  INTEGER                     NOT NULL REFERENCES reclamation_reasons(id),
  reason_description_ext     TEXT,
  reason_description_int     TEXT,
  position                   INTEGER                     NOT NULL CHECK(position > 0),
  itime                      TIMESTAMP without time zone DEFAULT now(),
  mtime                      TIMESTAMP without time zone,
--header
  project_id                 INTEGER                     REFERENCES project(id) ON DELETE SET NULL,
--part description
  parts_id                   INTEGER                     NOT NULL REFERENCES parts(id),
  description                TEXT,
  longdescription            TEXT,
  serialnumber               TEXT,
  base_qty                   REAL,
  qty                        REAL,
  unit                       character varying(20)       REFERENCES units(name),
--money
  sellprice                  NUMERIC(15,5),
  lastcost                   NUMERIC(15,5),
  discount                   REAL,
  pricegroup_id              INTEGER                     REFERENCES pricegroup(id),
  price_factor_id            INTEGER                     REFERENCES price_factors(id),
  price_factor               NUMERIC(15,5)               DEFAULT 1,
  active_price_source        TEXT                        NOT NULL DEFAULT ''::text,
  active_discount_source     TEXT                        NOT NULL DEFAULT ''::text,
--other
  reqdate                    DATE
);
CREATE TRIGGER mtime_reclamation_items BEFORE UPDATE ON reclamation_items FOR EACH ROW EXECUTE PROCEDURE set_mtime();
