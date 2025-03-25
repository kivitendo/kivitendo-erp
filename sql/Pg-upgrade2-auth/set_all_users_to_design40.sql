-- @tag: set_all_users_to_design40
-- @description: Alle Benutzer werden einmalig auf die Stilvorlage design40.css gesetzt. (Die Einstellung kann manuell in den Benutzereinstellungen rückgängig gemacht werden.)
-- @depends: release_3_9_1

UPDATE auth.user_config SET cfg_value = 'design40.css'
  WHERE cfg_key = 'stylesheet';
