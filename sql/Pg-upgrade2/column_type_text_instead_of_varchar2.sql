-- @tag: column_type_text_instead_of_varchar2
-- @description: Spaltentyp auf Text anstelle von varchar() für diverse Spalten Teil 2
-- @depends: column_type_text_instead_of_varchar

-- shipto
ALTER TABLE shipto
    ALTER COLUMN shiptocity         TYPE TEXT
  , ALTER COLUMN shiptocontact      TYPE TEXT
  , ALTER COLUMN shiptocountry      TYPE TEXT
  , ALTER COLUMN shiptodepartment_1 TYPE TEXT
  , ALTER COLUMN shiptodepartment_2 TYPE TEXT
  , ALTER COLUMN shiptofax          TYPE TEXT
  , ALTER COLUMN shiptoname         TYPE TEXT
  , ALTER COLUMN shiptophone        TYPE TEXT
  , ALTER COLUMN shiptostreet       TYPE TEXT
  , ALTER COLUMN shiptozipcode      TYPE TEXT
  ;
