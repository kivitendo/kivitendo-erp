-- @tag: custom_variables_valid
-- @description: Benutzerdefinierte Variablen als ungültig markieren.
-- @depends: release_2_6_0 custom_variables
CREATE TABLE custom_variables_validity (
       id        integer NOT NULL DEFAULT nextval('id'::text),
       config_id integer NOT NULL,
       trans_id  integer NOT NULL,

       itime timestamp DEFAULT now(),

       PRIMARY KEY (id),
       FOREIGN KEY (config_id) REFERENCES custom_variable_configs (id)
);
