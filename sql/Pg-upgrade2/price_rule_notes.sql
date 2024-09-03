-- @tag: price_rule_notes
-- @description: Preisregel Bemerkungen
-- @depends: release_3_9_0 price_rules_macros

ALTER TABLE price_rules ADD COLUMN notes TEXT DEFAULT '';
