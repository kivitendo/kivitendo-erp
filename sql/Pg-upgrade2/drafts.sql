-- @tag: drafts
-- @description: Neue Tabelle zum Speichern von Entw&uuml;rfen
-- @depends: release_2_4_1
CREATE TABLE drafts (
       id varchar(50) NOT NULL,
       module varchar(50) NOT NULL,
       submodule varchar(50) NOT NULL,
       description text,
       itime timestamp DEFAULT now(),
       form text,
       employee_id integer,

       PRIMARY KEY (id),
       FOREIGN KEY (employee_id) REFERENCES employee (id)
);
