-- @tag: custom_variables
-- @description: Benutzerdefinierte Variablen f&uuml;r beliebige Module. Hier nur f&uuml;r Kunden- und Lieferantenstammdaten implementiert.
-- @depends: release_2_4_3
CREATE SEQUENCE custom_variable_configs_id;
CREATE TABLE custom_variable_configs (
       id integer NOT NULL DEFAULT nextval('custom_variable_configs_id'),
       name text,
       description text,
       type varchar(20),
       module varchar(20),
       default_value text,
       options text,
       searchable boolean,
       includeable boolean,
       included_by_default boolean,
       sortkey integer,

       itime timestamp DEFAULT now(),
       mtime timestamp,

       PRIMARY KEY (id)
);

CREATE TRIGGER mtime_custom_variable_configs
    BEFORE UPDATE ON custom_variable_configs
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();

CREATE SEQUENCE custom_variables_id;
CREATE TABLE custom_variables (
       id integer NOT NULL DEFAULT nextval('custom_variables_id'),
       config_id integer NOT NULL,
       trans_id integer NOT NULL,

       bool_value boolean,
       timestamp_value timestamp,
       text_value text,
       number_value numeric(25,5),

       itime timestamp DEFAULT now(),
       mtime timestamp,

       PRIMARY KEY (id),
       FOREIGN KEY (config_id) REFERENCES custom_variable_configs (id)
);

CREATE TRIGGER mtime_custom_variables
    BEFORE UPDATE ON custom_variables
    FOR EACH ROW
    EXECUTE PROCEDURE set_mtime();

