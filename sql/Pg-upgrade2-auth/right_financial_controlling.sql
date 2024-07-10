-- @tag: right_financial_controlling
-- @description: eigenes Recht für Finanz-Controlling-Bericht
-- @depends: release_3_9_0 add_master_rights master_rights_position_gaps
-- @locales: Show sales financial controlling

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position - 40 FROM auth.master_rights WHERE name = 'delivery_plan'),
          'sales_financial_controlling',
          'Show sales financial controlling',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT DISTINCT(id), 'sales_financial_controlling', TRUE
    FROM auth.group
    LEFT JOIN auth.group_rights ON (auth.group.id = auth.group_rights.group_id)
    WHERE "right" LIKE 'sales_order_edit' AND granted IS TRUE;
