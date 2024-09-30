-- @tag: right_sales_report
-- @description: eigenes Recht für Verkaufsbericht
-- @depends: release_3_9_0 add_master_rights master_rights_position_gaps
-- @locales: Show sales report

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position - 30 FROM auth.master_rights WHERE name = 'delivery_plan'),
          'sales_report',
          'Show sales report',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT DISTINCT(id), 'sales_report', TRUE
    FROM auth.group
    LEFT JOIN auth.group_rights ON (auth.group.id = auth.group_rights.group_id)
    WHERE "right" LIKE 'invoice_edit' AND granted IS TRUE;
