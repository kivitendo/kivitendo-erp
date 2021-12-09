-- @tag: rights_for_reclamation
-- @description: Add rights for reclamation
-- @depends: release_3_5_7
-- @locales: Create and edit sales reclamation
-- @locales: Create and edit purchase reclamation

INSERT INTO auth.master_rights (position, name, description, category)
VALUES (1150, 'sales_reclamation_edit', 'Create and edit sales reclamation', false);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT id, 'sales_reclamation_edit', true
  FROM auth.group
  WHERE name = 'Vollzugriff';

INSERT INTO auth.master_rights (position, name, description, category)
VALUES (2450, 'purchase_reclamation_edit', 'Create and edit purchase reclamation', false);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT id, 'purchase_reclamation_edit', true
  FROM auth.group
  WHERE name = 'Vollzugriff';

