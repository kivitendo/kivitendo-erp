-- @tag: custom_variable_partsgroups
-- @description: Beziehung zwischen cvar configs und partsgroups für Filter nach Warengruppen
-- @depends: release_3_1_0

CREATE TABLE custom_variable_config_partsgroups (
  custom_variable_config_id integer NOT NULL,
  partsgroup_id             integer NOT NULL,

  itime                     timestamp              DEFAULT now(),
  mtime                     timestamp,

  FOREIGN KEY (custom_variable_config_id) REFERENCES custom_variable_configs(id),
  FOREIGN KEY (partsgroup_id)             REFERENCES partsgroup(id),

  PRIMARY KEY(custom_variable_config_id, partsgroup_id)
);

CREATE TRIGGER mtime_custom_variable_config_partsgroups BEFORE UPDATE ON custom_variable_config_partsgroups
    FOR EACH ROW EXECUTE PROCEDURE set_mtime();
