-- @tag: create_record_template_tables
-- @description: Einführung echter Vorlagen in der Finanzbuchhaltung anstelle der Entwurfsfunktion
-- @depends: release_3_4_1

DROP TABLE IF EXISTS record_template_items;
DROP TABLE IF EXISTS record_templates;
DROP TYPE IF EXISTS record_template_type;

CREATE TYPE record_template_type AS ENUM ('ar_transaction', 'ap_transaction', 'gl_transaction');
CREATE TABLE record_templates (
  id             SERIAL,
  template_name  TEXT                 NOT NULL,
  template_type  record_template_type NOT NULL,

  customer_id    INTEGER,
  vendor_id      INTEGER,
  currency_id    INTEGER              NOT NULL,
  department_id  INTEGER,
  project_id     INTEGER,
  employee_id    INTEGER,
  taxincluded    BOOLEAN              NOT NULL DEFAULT FALSE,
  direct_debit   BOOLEAN              NOT NULL DEFAULT FALSE,
  ob_transaction BOOLEAN              NOT NULL DEFAULT FALSE,
  cb_transaction BOOLEAN              NOT NULL DEFAULT FALSE,

  reference      TEXT,
  description    TEXT,
  ordnumber      TEXT,
  notes          TEXT,
  ar_ap_chart_id INTEGER,

  itime          TIMESTAMP            NOT NULL DEFAULT now(),
  mtime          TIMESTAMP            NOT NULL DEFAULT now(),

  PRIMARY KEY (id),
  CONSTRAINT record_templates_customer_id_fkey    FOREIGN KEY (customer_id)    REFERENCES customer   (id) ON DELETE SET NULL,
  CONSTRAINT record_templates_vendor_id_fkey      FOREIGN KEY (vendor_id)      REFERENCES vendor     (id) ON DELETE SET NULL,
  CONSTRAINT record_templates_currency_id_fkey    FOREIGN KEY (currency_id)    REFERENCES currencies (id) ON DELETE CASCADE,
  CONSTRAINT record_templates_department_id_fkey  FOREIGN KEY (department_id)  REFERENCES department (id) ON DELETE SET NULL,
  CONSTRAINT record_templates_project_id_fkey     FOREIGN KEY (project_id)     REFERENCES project    (id) ON DELETE SET NULL,
  CONSTRAINT record_templates_employee_id_fkey    FOREIGN KEY (employee_id)    REFERENCES employee   (id) ON DELETE SET NULL,
  CONSTRAINT record_templates_ar_ap_chart_id_fkey FOREIGN KEY (ar_ap_chart_id) REFERENCES chart      (id) ON DELETE SET NULL
);

CREATE TRIGGER mtime_record_templates BEFORE UPDATE ON record_templates FOR EACH ROW EXECUTE PROCEDURE set_mtime();

CREATE TABLE record_template_items (
  id                 SERIAL,
  record_template_id INTEGER         NOT NULL,

  chart_id           INTEGER         NOT NULL,
  tax_id             INTEGER         NOT NULL,
  project_id         INTEGER,
  amount1            NUMERIC (15, 5) NOT NULL,
  amount2            NUMERIC (15, 5),
  source             TEXT,
  memo               TEXT,

  PRIMARY KEY (id),
  CONSTRAINT record_template_items_record_template_id FOREIGN KEY (record_template_id) REFERENCES record_templates (id) ON DELETE CASCADE,
  CONSTRAINT record_template_items_chart_id           FOREIGN KEY (chart_id)           REFERENCES chart            (id) ON DELETE CASCADE,
  CONSTRAINT record_template_items_tax_id             FOREIGN KEY (tax_id)             REFERENCES tax              (id) ON DELETE CASCADE,
  CONSTRAINT record_template_items_project_id         FOREIGN KEY (project_id)         REFERENCES project          (id) ON DELETE SET NULL
);
