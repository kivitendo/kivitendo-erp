-- @tag: right_time_recording
-- @description: Recht zur Zeiterfassung
-- @depends: release_3_5_6_1
-- @locales: Create, edit and list time recordings

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 10 FROM auth.master_rights WHERE name = 'productivity'),
          'time_recording',
          'Create, edit and list time recordings',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT id, 'time_recording', true
  FROM auth.group
  WHERE name = 'Vollzugriff';
