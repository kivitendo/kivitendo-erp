-- @tag: remove_role_from_employee
-- @description: Nicht benutzte Spalte employee.role entfernen
-- @depends: clients
ALTER TABLE employee DROP COLUMN role;
