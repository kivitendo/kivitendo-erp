-- @tag: skr04_fix_category_3151_3160_3170
-- @description: Falscher Kontentyp von 3151, 3160, 3170 im SKR04
-- @depends: release_2_6_1
UPDATE chart
  SET category = 'L'
  WHERE (accno IN ('3151', '3160', '3170'))
    AND ((SELECT coa FROM defaults LIMIT 1) = 'Germany-DATEV-SKR04EU');
