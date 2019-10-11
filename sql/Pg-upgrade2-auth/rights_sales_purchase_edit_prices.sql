-- @tag: rights_sales_purchase_edit_prices
-- @description: Recht zum Bearbeiten von Preisen nach Ver- und Einkauf trennen
-- @depends: release_3_5_4 right_purchase_all_edit

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'purchase_all_edit'),
          'purchase_edit_prices',
          'Edit prices and discount (if not used, textfield is ONLY set readonly)',
          FALSE);

-- same rights as edit_prices because sales and purchase were not distingushed before
INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT group_id, 'purchase_edit_prices', granted FROM auth.group_rights WHERE "right" = 'edit_prices';

-- rename "edit_prices" to "sales_edit_prices"
UPDATE auth.master_rights SET name    = 'sales_edit_prices' WHERE name    = 'edit_prices';
UPDATE auth.group_rights  SET "right" = 'sales_edit_prices' WHERE "right" = 'edit_prices';
