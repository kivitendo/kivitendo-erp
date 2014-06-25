-- @tag: column_type_text_instead_of_varchar3
-- @description: Spaltentyp Text anstelle von varchar() in diversen Tabellen Teil 3
-- @depends: column_type_text_instead_of_varchar2

-- vendor
ALTER TABLE vendor ALTER COLUMN language TYPE TEXT;
