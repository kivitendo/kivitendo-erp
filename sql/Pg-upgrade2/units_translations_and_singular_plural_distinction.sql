-- @tag: units_translations_and_singular_plural_distinction
-- @description: F&uuml;r jede Einheit kann f&uuml;r jede Sprache eine &Uuml;bersetzung sowie eine Unterscheidung zwischen Singular und Plural gespeichert werden.
-- @depends:
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
