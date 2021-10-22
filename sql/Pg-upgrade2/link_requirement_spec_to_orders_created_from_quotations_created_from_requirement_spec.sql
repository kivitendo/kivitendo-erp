-- @tag: link_requirement_spec_to_orders_created_from_quotations_created_from_requirement_spec
-- @description: Pflichtenhefte mit Aufträgen verknüpfen, die aus Angeboten erstellt wurden, die wiederum aus einem Pflichtenheft erstellt wurden
-- @depends: release_3_2_0
CREATE TEMPORARY TABLE temp_link_requirement_spec_to_orders AS
SELECT rs_orders.requirement_spec_id, orders.id AS order_id, rs_orders.version_id
FROM record_links rl,
  requirement_spec_orders rs_orders,
  oe quotations,
  oe orders
WHERE (rl.from_table      = 'oe')
  AND (rl.from_id         = quotations.id)
  AND (rl.to_table        = 'oe')
  AND (rl.to_id           = orders.id)
  AND (rs_orders.order_id = quotations.id)
  AND     COALESCE(quotations.quotation, FALSE)
  AND NOT COALESCE(orders.quotation,     FALSE)
  AND (quotations.customer_id IS NOT NULL)
  AND (orders.customer_id     IS NOT NULL);

INSERT INTO requirement_spec_orders (requirement_spec_id, order_id, version_id)
SELECT requirement_spec_id, order_id, version_id
FROM temp_link_requirement_spec_to_orders new_orders
WHERE NOT EXISTS (
  SELECT existing_orders.id
  FROM requirement_spec_orders existing_orders
  WHERE (existing_orders.requirement_spec_id = new_orders.requirement_spec_id)
    AND (existing_orders.order_id            = new_orders.order_id)
  LIMIT 1
);
