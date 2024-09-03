-- @tag: price_rules_macros_migration
-- @description: Preisregeln auf die neue Macrostruktur migrieren
-- @depends: release_3_9_0 price_rules_macros

-- temp column to remember which price_rule made which macro
ALTER TABLE price_rule_macros ADD COLUMN price_rules_id INTEGER;

-- copy price_rules to price_rule_macros
INSERT INTO price_rule_macros (name, type, priority, obsolete, itime, mtime, json_definition, price_rules_id)
SELECT name, type, priority, obsolete, itime, mtime, row_to_json(
  (SELECT r FROM (SELECT name, type, priority, obsolete, itime, mtime, condition, action, '1' as format_version) r)
) AS json_definition, price_rules_id
FROM (
  -- 3. make the fitting actions
  SELECT price_rules_id, condition, row_to_json((SELECT r FROM (SELECT 'simple_action' AS type, price, discount, reduction) r)) AS action FROM (
    -- 2. make aggregated conditions from those.
    SELECT price_rules_id, json_agg(row_to_json) AS condition FROM (
      -- 1. make json representations of all the price_rule_items
      SELECT price_rules_id, row_to_json((SELECT r FROM (SELECT type, op, value_num as qty) r))
      FROM price_rule_items WHERE type = 'qty'
      UNION ALL
      SELECT price_rules_id, row_to_json((SELECT r FROM (SELECT type, value_int as id) r))
      FROM price_rule_items WHERE type IN ('customer', 'vendor', 'business', 'partsgroup', 'part', 'pricegroup')
      UNION ALL
      SELECT price_rules_id, row_to_json((SELECT r FROM (SELECT type, op, value_date as date) r))
      FROM price_rule_items WHERE type IN ('reqdate', 'transdate')
    ) items GROUP BY price_rules_id
  ) agg_items
  LEFT JOIN price_rules ON price_rules.id = price_rules_id
) action_condition
LEFT JOIN price_rules ON price_rules.id = price_rules_id
WHERE price_rules.price_rule_macro_id IS NULL AND NOT price_rules.obsolete;

-- copy id back
UPDATE price_rules SET price_rule_macro_id = subquery.id FROM (
  SELECT id, price_rules_id FROM price_rule_macros
) AS subquery
WHERE subquery.price_rules_id = price_rules.id;

-- drop temp table
ALTER TABLE price_rule_macros DROP COLUMN price_rules_id;

