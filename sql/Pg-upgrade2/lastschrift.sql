-- @tag: direct_debit 
-- @description: Schalter fuer Lastschrift
-- @depends: release_2_4_3
ALTER TABLE customer ADD COLUMN direct_debit boolean;
ALTER TABLE customer ALTER direct_debit SET DEFAULT false;
ALTER TABLE vendor ADD COLUMN  direct_debit boolean;
ALTER TABLE vendor ALTER direct_debit SET DEFAULT false;
