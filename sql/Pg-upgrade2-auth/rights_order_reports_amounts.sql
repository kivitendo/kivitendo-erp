-- @tag: rights_order_reports_amounts
-- @description: Rechte, um Auftragslisten mit Preisen zu sehen
-- @depends: release_3_9_0 add_master_rights master_rights_position_gaps
-- @locales: Show sales order reports with amounts (and links to open documents)
-- @locales: Show purchase order reports with amounts (and links to open documents)

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 5 FROM auth.master_rights WHERE name = 'sales_order_view'),
          'sales_order_reports_amounts',
          'Show sales order reports with amounts (and links to open documents)',
          FALSE);

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 5 FROM auth.master_rights WHERE name = 'purchase_order_view'),
          'purchase_order_reports_amounts',
          'Show purchase order reports with amounts (and links to open documents)',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT DISTINCT(id), 'sales_order_reports_amounts', TRUE
    FROM auth.group
    LEFT JOIN auth.group_rights ON (auth.group.id = auth.group_rights.group_id)
    WHERE ("right" LIKE 'sales_order_edit' AND granted = TRUE)
       OR ("right" LIKE 'sales_order_view' AND granted = TRUE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT DISTINCT(id), 'purchase_order_reports_amounts', TRUE
    FROM auth.group
    LEFT JOIN auth.group_rights ON (auth.group.id = auth.group_rights.group_id)
    WHERE ("right" LIKE 'purchase_order_edit' AND granted = TRUE)
       OR ("right" LIKE 'purchase_order_view' AND granted = TRUE);
