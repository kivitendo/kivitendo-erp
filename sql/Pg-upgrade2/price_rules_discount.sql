-- @tag: price_rules_discount
-- @description:  Preisregeln: Beim Löschen items mitlöschen
-- @depends: release_3_1_0 price_rules_cascade_delete

ALTER TABLE price_rules RENAME COLUMN discount TO reduction;
ALTER TABLE price_rules ADD COLUMN discount NUMERIC(15,5);
