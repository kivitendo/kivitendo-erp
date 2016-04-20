-- @tag: letter_cleanup
-- @description: Tabelle »letter«: Unbenutzte Spalten entfernen und andere Spalten umbenennen
-- @depends: release_3_4_0

ALTER TABLE letter       RENAME COLUMN vc_id TO customer_id;
ALTER TABLE letter_draft RENAME COLUMN vc_id TO customer_id;

ALTER TABLE letter
  DROP COLUMN close,
  DROP COLUMN company_name,
  DROP COLUMN employee_position,
  DROP COLUMN jobnumber,
  DROP COLUMN page_created_for,
  DROP COLUMN rcv_address,
  DROP COLUMN rcv_city,
  DROP COLUMN rcv_contact,
  DROP COLUMN rcv_country,
  DROP COLUMN rcv_countrycode,
  DROP COLUMN rcv_name,
  DROP COLUMN rcv_zipcode,
  DROP COLUMN salesman_position,
  DROP COLUMN text_created_for,
  ADD FOREIGN KEY (customer_id) REFERENCES customer (id);

ALTER TABLE letter_draft
  DROP COLUMN close,
  DROP COLUMN company_name,
  DROP COLUMN employee_position,
  DROP COLUMN jobnumber,
  DROP COLUMN page_created_for,
  DROP COLUMN rcv_address,
  DROP COLUMN rcv_city,
  DROP COLUMN rcv_contact,
  DROP COLUMN rcv_country,
  DROP COLUMN rcv_countrycode,
  DROP COLUMN rcv_name,
  DROP COLUMN rcv_zipcode,
  DROP COLUMN salesman_position,
  DROP COLUMN text_created_for,
  ADD FOREIGN KEY (customer_id) REFERENCES customer (id);
