-- @tag: follow_up_created_for_employees
-- @description: Wiedervorlagen für mehrere Benutzer ermöglichen
-- @depends: follow_ups

CREATE TABLE follow_up_created_for_employees (
       id            SERIAL   NOT NULL PRIMARY KEY,
       follow_up_id  INTEGER  NOT NULL REFERENCES follow_ups(id) ON DELETE CASCADE,
       employee_id   INTEGER  NOT NULL REFERENCES employee(id)
);

INSERT INTO follow_up_created_for_employees (follow_up_id, employee_id)
  SELECT id, created_for_user FROM follow_ups;

ALTER TABLE follow_ups DROP COLUMN created_for_user;
