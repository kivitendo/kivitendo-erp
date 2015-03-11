-- @tag: letter_emplyee_salesman
-- @description: Briefe: Fußfelder sind nicht mehr Pflicht.
-- @depends: letter_country_page

ALTER TABLE letter ALTER COLUMN employee_id DROP NOT NULL;
ALTER TABLE letter ALTER COLUMN salesman_id DROP NOT NULL;


