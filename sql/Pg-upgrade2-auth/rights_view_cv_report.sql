-- @tag: rights_view_cv_report
-- @description: Recht, um auf Kunden-/Lieferanten-Stammdaten-Bericht zugreifen zu können
-- @depends: release_3_9_0 add_master_rights master_rights_position_gaps
-- @locales: View customer report
-- @locales: View vendor report

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'customer_vendor_all_edit'),
          'customer_report_view',
          'View customer report',
          FALSE);

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'customer_report_view'),
          'vendor_report_view',
          'View vendor report',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT DISTINCT(id), 'customer_report_view', TRUE
    FROM auth.group;

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT DISTINCT(id), 'vendor_report_view', TRUE
    FROM auth.group;
