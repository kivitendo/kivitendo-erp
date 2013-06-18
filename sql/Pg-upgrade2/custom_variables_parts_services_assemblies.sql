-- @tag: custom_variables_parts_services_assemblies
-- @description: Benutzerdefinierte Variablen für Waren, Dienstleistungen, Erzeugnisse.
-- @depends: release_2_6_0
ALTER TABLE custom_variable_configs ADD COLUMN flags text;
ALTER TABLE custom_variables ADD COLUMN sub_module text;
UPDATE custom_variables SET sub_module = '';
