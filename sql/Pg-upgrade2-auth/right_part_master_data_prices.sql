-- @tag: right_part_master_data_prices
-- @description: Recht, um Preise in Artikelstammdaten zu bearbeiten
-- @depends: release_3_9_0 add_master_rights master_rights_position_gaps
-- @locales: Edit prices for parts, services, assemblies

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'part_service_assembly_edit'),
          'part_service_assembly_edit_prices',
          'Edit prices for parts, services, assemblies',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT DISTINCT(id), 'part_service_assembly_edit_prices', TRUE
    FROM auth.group
    LEFT JOIN auth.group_rights ON (auth.group.id = auth.group_rights.group_id)
    WHERE "right" LIKE 'part_service_assembly_edit';
