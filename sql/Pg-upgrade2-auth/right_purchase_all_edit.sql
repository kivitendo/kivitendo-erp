-- @tag: right_purchase_all_edit
-- @description: Recht zum Bearbeiten von Einkaufsdokumenten aller Mitarbeiter (Trennung nach VK u. EK)
-- @depends: release_3_5_4
-- @locales: View/edit all employees purchase documents

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'purchase_letter_edit'),
          'purchase_all_edit',
          'View/edit all employees purchase documents',
          FALSE);

-- same rights as sales_all_edit because sales and purchase were not distingushed before
INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT group_id, 'purchase_all_edit', granted FROM auth.group_rights WHERE "right" = 'sales_all_edit';
