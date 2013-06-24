-- @tag: invalid_entries_in_custom_variables_validity
-- @description: Ungültige Einträge in custom_variables_validity bereinigen
-- @depends: release_2_6_1
DELETE FROM custom_variables_validity
WHERE trans_id NOT IN (
  SELECT id
  FROM parts
);
