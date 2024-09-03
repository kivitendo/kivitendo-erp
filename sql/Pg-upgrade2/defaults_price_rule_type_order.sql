-- @tag: defaults_price_rule_type_order
-- @description: Reiehnfolge der Typspalten in der Preisregelsuche
-- @depends: release_3_9_0 price_rule_macro_foreign_key

ALTER TABLE defaults ADD COLUMN price_rule_type_order text[];
