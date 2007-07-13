-- @tag: employee_no_limits
-- @description: Keine L&auml;ngenbeschr&auml;nkung f&uuml;r Spalten in der Tabelle employee.
-- @depends: release_2_4_1
ALTER TABLE employee ADD COLUMN tmp_name text;
ALTER TABLE employee ADD COLUMN tmp_addr1 text;
ALTER TABLE employee ADD COLUMN tmp_addr2 text;
ALTER TABLE employee ADD COLUMN tmp_addr3 text;
ALTER TABLE employee ADD COLUMN tmp_addr4 text;
ALTER TABLE employee ADD COLUMN tmp_homephone text;
ALTER TABLE employee ADD COLUMN tmp_workphone text;

UPDATE employee SET tmp_name = name, tmp_addr1 = addr1, tmp_addr2 = addr2, tmp_addr3 = addr3, tmp_addr4 = addr4, tmp_homephone = homephone, tmp_workphone = workphone;

ALTER TABLE employee DROP COLUMN name;
ALTER TABLE employee RENAME tmp_name TO name;
ALTER TABLE employee DROP COLUMN addr1;
ALTER TABLE employee RENAME tmp_addr1 TO addr1;
ALTER TABLE employee DROP COLUMN addr2;
ALTER TABLE employee RENAME tmp_addr2 TO addr2;
ALTER TABLE employee DROP COLUMN addr3;
ALTER TABLE employee RENAME tmp_addr3 TO addr3;
ALTER TABLE employee DROP COLUMN addr4;
ALTER TABLE employee RENAME tmp_addr4 TO addr4;
ALTER TABLE employee DROP COLUMN homephone;
ALTER TABLE employee RENAME tmp_homephone TO homephone;
ALTER TABLE employee DROP COLUMN workphone;
ALTER TABLE employee RENAME tmp_workphone TO workphone;

CREATE INDEX employee_name_key ON employee ( name );
