-- @tag: add_batch_printing_to_full_access
-- @description: Gruppe "Vollzugriff" Recht auf Stapeldruck-Menü gewähren
-- @depends:
DELETE FROM auth.group_rights
WHERE ("right" = 'batch_printing')
  AND group_id = (
    SELECT id
    FROM auth."group"
    WHERE name = 'Vollzugriff'
  );

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT id, 'batch_printing', TRUE
  FROM auth."group"
  WHERE name = 'Vollzugriff';
