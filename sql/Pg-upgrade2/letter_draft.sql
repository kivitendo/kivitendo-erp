-- @tag: letter_draft
-- @description: Briefentwürfe Felder
-- @depends: release_3_2_0 letter

CREATE TABLE letter_draft (
  id INTEGER NOT NULL DEFAULT nextval('id'),
  vc_id INTEGER NOT NULL,
  cp_id INTEGER,
  rcv_name TEXT,
  rcv_contact TEXT,
  rcv_address TEXT,
  rcv_countrycode TEXT,
  rcv_zipcode TEXT,
  rcv_city TEXT,
  rcv_country TEXT,
  page_created_for TEXT,
  letternumber TEXT,
  jobnumber TEXT,
  text_created_for TEXT,
  date DATE,
  intnotes TEXT,

  reference TEXT,
  subject TEXT,
  greeting TEXT,
  body TEXT,
  close TEXT,
  company_name TEXT,

  employee_id INTEGER,
  employee_position TEXT,

  salesman_id INTEGER,
  salesman_position TEXT,

  itime TIMESTAMP DEFAULT now(),
  mtime TIMESTAMP,

  PRIMARY KEY (id),
  FOREIGN KEY (employee_id) REFERENCES employee (id),
  FOREIGN KEY (salesman_id) REFERENCES employee (id),
  FOREIGN KEY (cp_id) REFERENCES contacts(cp_id)
);

