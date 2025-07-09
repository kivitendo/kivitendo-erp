-- @tag: right_custom_data_report
-- @description: Recht, um benutzerdef. Berichte überhaupt nutzen zu können
-- @depends: release_3_9_0 add_master_rights master_rights_position_gaps
-- @locales: May use Custom Data Report at all

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 20 FROM auth.master_rights WHERE name = 'advance_turnover_tax_return'),
          'custom_data_report',
          'May use Custom Data Report at all',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT DISTINCT(id), 'custom_data_report', TRUE
    FROM auth.group
    LEFT JOIN auth.group_rights ON (auth.group.id = auth.group_rights.group_id)
    WHERE "right" LIKE 'report';
