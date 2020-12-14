-- @tag: right_productivity_as_category
-- @description: Rechte: Produktivität als eigene Kategorie
-- @depends: master_rights_positions_fix
-- @locales: Productivity (TODO list, Follow-Ups)

-- make space before 'configuration'
UPDATE auth.master_rights SET position = position+1000
  WHERE position >= (SELECT position FROM auth.master_rights WHERE name LIKE 'configuration');

-- insert category for productivity before 'configuration'
INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position FROM auth.master_rights WHERE name LIKE 'configuration') - 1000,
          'productivity_category',
          'Productivity',
          TRUE);

-- move productivity rights below 'productivity_category'
UPDATE auth.master_rights SET position    = (SELECT position FROM auth.master_rights WHERE name LIKE 'productivity_category') + 100,
                              description = 'Productivity (TODO list, Follow-Ups)'
  WHERE name LIKE 'productivity';

UPDATE auth.master_rights SET position = (SELECT position FROM auth.master_rights WHERE name LIKE 'productivity_category') + 200
  WHERE name LIKE 'email_journal';

UPDATE auth.master_rights SET position = (SELECT position FROM auth.master_rights WHERE name LIKE 'productivity_category') + 250
  WHERE name LIKE 'email_employee_readall';
