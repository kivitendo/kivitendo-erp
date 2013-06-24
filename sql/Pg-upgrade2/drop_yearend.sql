-- @tag: drop_yearend 
-- @description: yearend wird nicht mehr benötigt, da closedto (Bücherabschluss) vorhanden ist
-- @depends: release_2_6_1
ALTER TABLE defaults DROP COLUMN yearend;
