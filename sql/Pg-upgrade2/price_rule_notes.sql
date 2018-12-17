-- @tag: price_rule_notes
-- @description: Preisregel Bemerkungen
-- @depends: release_18_12

ALTER TABLE price_rules ADD COLUMN notes TEXT DEFAULT '';
