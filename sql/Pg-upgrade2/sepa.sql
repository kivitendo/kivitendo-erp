-- @tag: sepa
-- @description: Tabellen für den SEPA-XML-Exportassistenten
-- @depends: release_2_6_0
-- @ignore: 0
--DROP TABLE sepa_export_items;
--DROP TABLE sepa_export;
--DROP SEQUENCE sepa_export_id_seq;

CREATE SEQUENCE sepa_export_id_seq;

CREATE TABLE sepa_export (
  id integer NOT NULL DEFAULT nextval('sepa_export_id_seq'),
  employee_id integer NOT NULL,
  executed boolean DEFAULT FALSE,
  closed boolean DEFAULT FALSE,
  itime timestamp DEFAULT now(),

  PRIMARY KEY (id),
  FOREIGN KEY (employee_id) REFERENCES employee (id)
);

CREATE TABLE sepa_export_items (
  id integer NOT NULL DEFAULT nextval('id'),
  sepa_export_id integer NOT NULL,
  ap_id integer NOT NULL,
  chart_id integer NOT NULL,
  amount NUMERIC(25,5),
  reference varchar(35),
  requested_execution_date date,
  executed boolean DEFAULT FALSE,
  execution_date date,

  our_iban varchar(100),
  our_bic varchar(100),
  vendor_iban varchar(100),
  vendor_bic varchar(100),

  end_to_end_id varchar(35),

  PRIMARY KEY (id),
  FOREIGN KEY (sepa_export_id) REFERENCES sepa_export (id),
  FOREIGN KEY (ap_id) REFERENCES ap (id),
  FOREIGN KEY (chart_id) REFERENCES chart (id)
);
