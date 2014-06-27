-- @tag: column_type_text_instead_of_varchar
-- @description: Spaltentyp auf Text anstelle von varchar() für diverse Spalten
-- @depends: release_3_1_0

-- contacts
ALTER TABLE contacts
    ALTER COLUMN cp_givenname TYPE TEXT
  , ALTER COLUMN cp_title     TYPE TEXT
  , ALTER COLUMN cp_name      TYPE TEXT
  , ALTER COLUMN cp_phone1    TYPE TEXT
  , ALTER COLUMN cp_phone2    TYPE TEXT
  , ALTER COLUMN cp_position  TYPE TEXT
  ;

-- customer
ALTER TABLE customer
    ALTER COLUMN bic          TYPE TEXT
  , ALTER COLUMN city         TYPE TEXT
  , ALTER COLUMN country      TYPE TEXT
  , ALTER COLUMN department_1 TYPE TEXT
  , ALTER COLUMN department_2 TYPE TEXT
  , ALTER COLUMN fax          TYPE TEXT
  , ALTER COLUMN iban         TYPE TEXT
  , ALTER COLUMN language     TYPE TEXT
  , ALTER COLUMN street       TYPE TEXT
  , ALTER COLUMN username     TYPE TEXT
  , ALTER COLUMN zipcode      TYPE TEXT
  ;

-- vendor
ALTER TABLE vendor
    ALTER COLUMN bic           TYPE TEXT
  , ALTER COLUMN city          TYPE TEXT
  , ALTER COLUMN country       TYPE TEXT
  , ALTER COLUMN department_1  TYPE TEXT
  , ALTER COLUMN department_2  TYPE TEXT
  , ALTER COLUMN fax           TYPE TEXT
  , ALTER COLUMN iban          TYPE TEXT
  , ALTER COLUMN street        TYPE TEXT
  , ALTER COLUMN user_password TYPE TEXT
  , ALTER COLUMN username      TYPE TEXT
  , ALTER COLUMN zipcode       TYPE TEXT
  ;
