-- @tag: rights_time_recording_show_edit_all
-- @description: Rechte, Zeiterfassungseinträge aller Mitarbeiter anzuzeigen bzw. zu bearbeiten
-- @depends: right_time_recording
-- @locales: List time recordings of all staff members
-- @locales: Edit time recordings of all staff members

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 20 FROM auth.master_rights WHERE name = 'time_recording'),
          'time_recording_show_all',
          'List time recordings of all staff members',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT id, 'time_recording_show_all', true
  FROM auth.group
  WHERE name = 'Vollzugriff';

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 20 FROM auth.master_rights WHERE name = 'time_recording_show_all'),
          'time_recording_edit_all',
          'Edit time recordings of all staff members',
          FALSE);

INSERT INTO auth.group_rights (group_id, "right", granted)
  SELECT id, 'time_recording_edit_all', true
  FROM auth.group
  WHERE name = 'Vollzugriff';
