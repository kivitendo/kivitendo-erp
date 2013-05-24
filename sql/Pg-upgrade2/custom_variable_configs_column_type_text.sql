-- @tag: custom_variable_configs_column_type_text
-- @description: Spaltentypen in 'custom_varialbe_configs' anpassen & schärfere Restriktionen
-- @depends: release_3_0_0
-- @charset: utf-8
ALTER TABLE custom_variable_configs ALTER COLUMN type   TYPE TEXT;
ALTER TABLE custom_variable_configs ALTER COLUMN module TYPE TEXT;

UPDATE custom_variable_configs SET searchable          = FALSE WHERE searchable          IS NULL;
UPDATE custom_variable_configs SET includeable         = FALSE WHERE includeable         IS NULL;
UPDATE custom_variable_configs SET included_by_default = FALSE WHERE included_by_default IS NULL;

ALTER TABLE custom_variable_configs ALTER COLUMN searchable          SET NOT NULL;
ALTER TABLE custom_variable_configs ALTER COLUMN includeable         SET NOT NULL;
ALTER TABLE custom_variable_configs ALTER COLUMN included_by_default SET NOT NULL;
ALTER TABLE custom_variable_configs ALTER COLUMN name                SET NOT NULL;
ALTER TABLE custom_variable_configs ALTER COLUMN description         SET NOT NULL;
ALTER TABLE custom_variable_configs ALTER COLUMN type                SET NOT NULL;
ALTER TABLE custom_variable_configs ALTER COLUMN module              SET NOT NULL;
ALTER TABLE custom_variable_configs ALTER COLUMN sortkey             SET NOT NULL;

ALTER TABLE custom_variable_configs
ADD CONSTRAINT custom_variable_configs_name_description_type_module_not_empty
CHECK (    type        <> ''
       AND module      <> ''
       AND name        <> ''
       AND description <> '');

ALTER TABLE custom_variable_configs
ADD CONSTRAINT custom_variable_configs_options_not_empty_for_select
CHECK ((type <> 'select') OR (COALESCE(options, '') <> ''));
