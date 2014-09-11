-- @tag: price_rules_cascade_delete
-- @description:  Preisregeln: Beim Löschen items mitlöschen
-- @depends: release_3_1_0 price_rules

ALTER TABLE price_rule_items DROP CONSTRAINT "price_rule_items_price_rules_id_fkey";
ALTER TABLE price_rule_items ADD FOREIGN KEY (price_rules_id) REFERENCES price_rules(id) ON DELETE CASCADE;
