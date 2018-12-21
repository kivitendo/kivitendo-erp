-- @tag: price_rule_macro_notes
-- @description: Preisregelmacro Bemerkungen
-- @depends: release_18_12 price_rule_notes

ALTER TABLE price_rule_macros ADD COLUMN notes TEXT DEFAULT '';
