-- @tag: direct_debit 
-- @description: Schalter fuer Lastschrift
-- @depends: release_2_4_3
ALTER TABLE customer ADD COLUMN direct_debit boolean DEFAULT false;
ALTER TABLE vendor ADD COLUMN  direct_debit boolean DEFAULT false;
