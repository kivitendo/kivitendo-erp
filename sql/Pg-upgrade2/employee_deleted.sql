-- @tag: employee_deleted
-- @description: Benutzer löschbar machen
-- @depends: release_2_6_3
-- @charset: utf-8

ALTER TABLE employee ADD COLUMN deleted BOOLEAN DEFAULT 'f';
