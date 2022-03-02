-- @tag: rights_view_docs
-- @description: Rechte zum Lesen von Belegen
-- @depends: release_3_6_0
-- @locales: View sales quotations
-- @locales: View sales orders
-- @locales: View sales delivery orders
-- @locales: View sales invoices and credit notes
-- @locales: View RFQs
-- @locales: View purchase orders
-- @locales: View purchase delivery orders
-- @locales: View purchase invoices

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'sales_quotation_edit'),
          'sales_quotation_view',
           'View sales quotations',
          FALSE);

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'sales_order_edit'),
          'sales_order_view',
           'View sales orders',
          FALSE);

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'sales_delivery_order_edit'),
          'sales_delivery_order_view',
           'View sales delivery orders',
          FALSE);

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'invoice_edit'),
          'sales_invoice_view',
          'View sales invoices and credit notes',
          FALSE);

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'request_quotation_edit'),
          'request_quotation_view',
           'View RFQs',
          FALSE);

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'purchase_order_edit'),
          'purchase_order_view',
           'View purchase orders',
          FALSE);

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'purchase_delivery_order_edit'),
          'purchase_delivery_order_view',
           'View purchase delivery orders',
          FALSE);

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'vendor_invoice_edit'),
          'purchase_invoice_view',
          'View purchase invoices',
          FALSE);


INSERT INTO auth.group_rights (group_id, "right", granted)
   SELECT (SELECT id FROM auth.group WHERE name = 'Vollzugriff'), 'sales_quotation_view',         true UNION
   SELECT (SELECT id FROM auth.group WHERE name = 'Vollzugriff'), 'sales_order_view',             true UNION
   SELECT (SELECT id FROM auth.group WHERE name = 'Vollzugriff'), 'sales_delivery_order_view',    true UNION
   SELECT (SELECT id FROM auth.group WHERE name = 'Vollzugriff'), 'sales_invoice_view',           true UNION
   SELECT (SELECT id FROM auth.group WHERE name = 'Vollzugriff'), 'request_quotation_view',       true UNION
   SELECT (SELECT id FROM auth.group WHERE name = 'Vollzugriff'), 'purchase_order_view',          true UNION
   SELECT (SELECT id FROM auth.group WHERE name = 'Vollzugriff'), 'purchase_delivery_order_view', true UNION
   SELECT (SELECT id FROM auth.group WHERE name = 'Vollzugriff'), 'purchase_invoice_view',        true;
