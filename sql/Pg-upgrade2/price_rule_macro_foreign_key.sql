-- @tag: price_rule_macro_foreign_key
-- @description: Preisregeln löschen - Datenbankkonsistenz
-- @depends: release_19_04 price_rules_macros

ALTER TABLE price_rules DROP CONSTRAINT "price_rules_price_rule_macros_id_fkey";
ALTER TABLE price_rules ADD FOREIGN KEY (price_rule_macro_id) REFERENCES price_rule_macros(id) ON DELETE CASCADE;
