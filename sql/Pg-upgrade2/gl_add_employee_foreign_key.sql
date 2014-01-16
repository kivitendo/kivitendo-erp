-- @tag: gl_add_employee_foreign_key
-- @description: Dialogbuchungen mit Bearbeiter verknüpfen
-- @depends: release_3_0_0
-- @ignore: 0
ALTER TABLE gl  ADD FOREIGN KEY (employee_id) REFERENCES employee(id);
