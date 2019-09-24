-- @tag: defaults_price_rule_type_order
-- @description: Reiehnfolge der Typspalten in der Preisregelsuche
-- @depends: release_19_05

ALTER TABLE defaults ADD COLUMN price_rule_type_order text[];
