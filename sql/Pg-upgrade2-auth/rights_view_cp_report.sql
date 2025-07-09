-- @tag: rights_view_cp_report
-- @description: Recht, um auf Ansprechpersonen-Bericht zugreifen zu können
-- @depends: release_3_9_0 add_master_rights master_rights_position_gaps rights_view_cv_report
-- @locales: View contact person report

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'vendor_report_view'),
          'contact_person_report_view',
          'View contact person report',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT DISTINCT(id), 'contact_person_report_view', TRUE
    FROM auth.group;
