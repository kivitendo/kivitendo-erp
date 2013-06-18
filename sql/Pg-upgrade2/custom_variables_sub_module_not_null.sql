-- @tag: custom_variables_sub_module_not_null
-- @description: sub_module in custom_variables auf NOT NULL ändern.
-- @depends: release_2_7_0
UPDATE custom_variables SET sub_module = '' WHERE sub_module IS NULL;
ALTER TABLE custom_variables ALTER COLUMN sub_module SET DEFAULT '';
ALTER TABLE custom_variables ALTER COLUMN sub_module SET NOT NULL;

