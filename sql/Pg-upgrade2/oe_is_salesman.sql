-- @tag: oe_is_salesman
-- @description: Speichern eines Verk&auml;ufers bei Angeboten und Ausgangsrechnungen
-- @depends: release_2_4_1
ALTER TABLE oe ADD COLUMN salesman_id integer;
ALTER TABLE oe ADD FOREIGN KEY (salesman_id) REFERENCES employee (id);
ALTER TABLE ar ADD COLUMN salesman_id integer;
ALTER TABLE ar ADD FOREIGN KEY (salesman_id) REFERENCES employee (id);
