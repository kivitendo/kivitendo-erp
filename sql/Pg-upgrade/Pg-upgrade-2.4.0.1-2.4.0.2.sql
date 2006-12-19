CREATE TABLE units_language (
       unit varchar (20) NOT NULL,
       language_id integer NOT NULL,
       localized varchar (20),
       localized_plural varchar (20),

       FOREIGN KEY (unit) REFERENCES units (name),
       FOREIGN KEY (language_id) REFERENCES language (id)
);
CREATE INDEX units_name_idx ON units (name);
CREATE INDEX units_language_unit_idx ON units_language (unit);
