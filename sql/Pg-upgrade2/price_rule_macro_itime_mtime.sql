-- @tag: price_rule_macro_itime_mtime
-- @description: Preisregeln mtime/itime Trigger
-- @depends: release_19_04 price_rules_macros

ALTER TABLE price_rules ALTER COLUMN itime SET DEFAULT now();
ALTER TABLE price_rule_macros ALTER COLUMN itime SET DEFAULT now();

CREATE TRIGGER mtime_price_rule_macros BEFORE UPDATE ON price_rule_macros FOR EACH ROW EXECUTE PROCEDURE set_mtime();
