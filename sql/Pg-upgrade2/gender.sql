-- @tag: gender
-- @description: Feld "Geschlecht" zu Kontaktdaten hinzufuegen, cp_greeting entferne
-- @depends: release_2_6_0

ALTER TABLE contacts ADD COLUMN cp_gender char(1);
UPDATE contacts SET cp_gender = 'm';
UPDATE contacts SET cp_gender = 'f'
  WHERE (cp_greeting ILIKE '%frau%')
     OR (cp_greeting ILIKE '%mrs.%')
     OR (cp_greeting ILIKE '%miss%');

UPDATE contacts SET cp_title = cp_greeting WHERE NOT (cp_greeting ILIKE '%frau%' OR cp_greeting ILIKE '%herr%' or cp_greeting ILIKE '%mrs.%' or cp_greeting ILIKE '%miss%');

ALtER TABLE contacts DROP COLUMN cp_greeting;
