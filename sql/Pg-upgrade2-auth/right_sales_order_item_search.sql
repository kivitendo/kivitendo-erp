-- @tag: right_sales_order_item_search
-- @description: eigenes Recht für Auftragsartikelsuche
-- @depends: release_3_9_0 add_master_rights master_rights_position_gaps
-- @locales: Show sales order item search

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position - 50 FROM auth.master_rights WHERE name = 'delivery_plan'),
          'sales_order_item_search',
          'Show sales order item search',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT DISTINCT(id), 'sales_order_item_search', TRUE
    FROM auth.group
    LEFT JOIN auth.group_rights ON (auth.group.id = auth.group_rights.group_id)
    WHERE "right" LIKE 'sales_order_edit' AND granted IS TRUE;
