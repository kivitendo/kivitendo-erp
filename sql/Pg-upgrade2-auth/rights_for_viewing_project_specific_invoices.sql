-- @tag: rights_for_viewing_project_specific_invoices
-- @description: Rechte zum Anzeigen von Rechnungen, die zu Projekten gehören
-- @depends: release_3_5_3
-- @locales: Projects: edit the list of employees allowed to view invoices
INSERT INTO auth.master_rights (position, name, description, category)
VALUES (
  (SELECT position + 2
   FROM auth.master_rights
   WHERE name = 'project_edit'),
  'project_edit_view_invoices_permission',
  'Projects: edit the list of employees allowed to view invoices',
  false
);

INSERT INTO auth.group_rights (group_id, "right", granted)
SELECT id, 'project_edit_view_invoices_permission', true
FROM auth.group
WHERE name = 'Vollzugriff';
