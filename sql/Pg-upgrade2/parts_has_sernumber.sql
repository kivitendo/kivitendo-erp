-- @tag: has_sernumber
-- @description: Artikel hat eine Seriennummer 
-- @depends: parts
has_sernumber      | boolean                     | default false
ALTER TABLE parts ADD COLUMN has_sernumber boolean;
ALTER TABLE parts ALTER COLUMN has_sernumber  SET DEFAULT false;
