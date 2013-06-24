-- @tag: project_customer_type_valid
-- @description: Projekt: Spalten "Kunde", "Typ", "Gültig"
-- @depends: release_3_0_0
ALTER TABLE project ADD COLUMN customer_id INTEGER;
ALTER TABLE project ADD COLUMN type TEXT;
ALTER TABLE project ADD COLUMN valid BOOLEAN;
ALTER TABLE project ALTER COLUMN valid SET DEFAULT TRUE;

ALTER TABLE project ADD FOREIGN KEY (customer_id) REFERENCES customer (id);

UPDATE project SET valid = TRUE;
