-- @tag: right_develop
-- @description: Recht für Entwickler
-- @depends: release_3_5_7
-- @locales: See various menu entries intended for developers

INSERT INTO auth.master_rights (position, name, description, category)
  VALUES ((SELECT position + 20 FROM auth.master_rights WHERE name = 'admin'),
          'developer',
          'See various menu entries intended for developers',
          FALSE);
