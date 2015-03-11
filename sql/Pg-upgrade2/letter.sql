-- @tag: letter
-- @description: Brieffunktion Felder
-- @depends: release_3_2_0

CREATE TABLE letter (
  id INTEGER NOT NULL DEFAULT nextval('id'),
  vc_id INTEGER NOT NULL,
  rcv_name TEXT,
  rcv_contact TEXT,
  rcv_address TEXT,
  rcv_countrycode TEXT,
  rcv_zipcode TEXT,
  rcv_city TEXT,

  letternumber TEXT,
  jobnumber TEXT,
  text_created_for TEXT,
  date TEXT,

  subject TEXT,
  greeting TEXT,
  body TEXT,
  close TEXT,
  company_name TEXT,

  employee_id INTEGER NOT NULL,
  employee_position TEXT,

  salesman_id INTEGER NOT NULL,
  salesman_position TEXT,

  itime TIMESTAMP DEFAULT now(),
  mtime TIMESTAMP,

  PRIMARY KEY (id),
  FOREIGN KEY (employee_id) REFERENCES employee (id),
  FOREIGN KEY (salesman_id) REFERENCES employee (id)
);

ALTER TABLE defaults ADD COLUMN letternumber integer;

