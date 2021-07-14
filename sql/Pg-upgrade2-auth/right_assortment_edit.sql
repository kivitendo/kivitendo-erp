-- @tag: right_assortment_edit
-- @description: Recht zum Ändern von Sortimentsbestandteilen auch nach Verwendeung
-- @depends: release_3_5_7 move_shop_part_edit_right
-- @locales: Always edit assortment items (user can change/delete items even if assortments are already used)

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'assembly_edit'),
          'assortment_edit',
          'Always edit assortment items (user can change/delete items even if assortments are already used)',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT id, 'assortment_edit', true
  FROM auth.group
  WHERE name = 'Vollzugriff';
