-- @tag: remove_role_from_employee
-- @description: Nicht benutzte Spalte employee.role entfernen
-- @depends: clients
-- @charset: utf-8
ALTER TABLE employee DROP COLUMN role;
