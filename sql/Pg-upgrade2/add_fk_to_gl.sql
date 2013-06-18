-- @tag: add_fk_to_gl
-- @description: Setzt Datenbank-Fremdschlüssel von gl.department_id auf department.id
-- @depends: release_3_0_0

-- update all invalid departments in gl:
UPDATE gl SET department_id = NULL WHERE department_id NOT IN (SELECT id FROM department);

-- drop default value:
ALTER TABLE gl ALTER department_id DROP DEFAULT;

-- set foreign key constraint:
ALTER TABLE gl ADD FOREIGN KEY (department_id) REFERENCES department(id);

