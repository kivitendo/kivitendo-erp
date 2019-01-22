-- @tag: customer_add_commercial_court
-- @description: Amtsgericht/Handelsgericht für Körperschaften bei den Stammdaten hinterlegen
-- @depends: release_3_5_3
ALTER TABLE customer ADD COLUMN commercial_court text;
