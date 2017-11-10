-- @tag: custom_data_export_default_values_for_parameters
-- @description: Bentuzerdefinierter Datenexport: Vorgabewerte für Parameter
-- @depends: custom_data_export
CREATE TYPE custom_data_export_query_parameter_default_value_type_enum AS ENUM ('none', 'current_user_login', 'sql_query', 'fixed_value');

ALTER TABLE custom_data_export_query_parameters
ADD COLUMN default_value_type custom_data_export_query_parameter_default_value_type_enum,
ADD COLUMN default_value      TEXT;

UPDATE custom_data_export_query_parameters
SET default_value_type = 'none';

ALTER TABLE custom_data_export_query_parameters
ALTER COLUMN default_value_type
SET NOT NULL;
