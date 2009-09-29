-- @tag: has_sernumber
-- @description: Artikel hat eine Seriennummer 
-- @depends: release_2_6_0
ALTER TABLE parts ADD COLUMN has_sernumber boolean;
ALTER TABLE parts ALTER COLUMN has_sernumber  SET DEFAULT false;
