-- @tag: status_history
-- @description: Spalten in Tabelle status zum Speichern der history
-- @depends: release_2_4_1
ALTER TABLE status ADD COLUMN id integer;
UPDATE status SET id = nextval('id');
ALTER TABLE status ALTER COLUMN id SET DEFAULT nextval('id');
ALTER TABLE status ALTER COLUMN id SET NOT NULL;

ALTER TABLE status ADD COLUMN employee_id integer;
ALTER TABLE status ADD FOREIGN KEY (employee_id) REFERENCES employee(id);

ALTER TABLE status ADD COLUMN addition text;
ALTER TABLE status ADD COLUMN what_done text;
