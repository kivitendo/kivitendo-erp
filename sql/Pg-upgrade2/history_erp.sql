-- @tag: history_erp
-- @description: Entfernen der Spalten in Tabelle status zum Speichern der history und daf&uuml;r eigene Tabelle f&uuml;r die history
-- @depends: status_history
ALTER TABLE status DROP COLUMN id;
ALTER TABLE status DROP COLUMN employee_id;
ALTER TABLE status DROP COLUMN addition;
ALTER TABLE status DROP COLUMN what_done;

CREATE TABLE history_erp (
       id integer NOT NULL DEFAULT nextval('id'),
       trans_id integer,
       employee_id integer,
       addition text,
       what_done text,
       itime timestamp DEFAULT now(),

       PRIMARY KEY (id),
       FOREIGN KEY (employee_id) REFERENCES employee (id)
);
