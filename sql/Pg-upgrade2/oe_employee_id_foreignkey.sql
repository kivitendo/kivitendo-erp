-- @tag: oe_employee_id_foreignkey  
-- @description: Falls ein Benutzer hart in der Datenbank gelöscht werden soll, müssen auch die Verknüpfung zu seinen bearbeitenden Aufträge bedacht werden
-- @depends: release_2_4_3
ALTER TABLE oe ADD FOREIGN KEY (employee_id) REFERENCES employee (id);
