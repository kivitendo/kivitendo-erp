-- @tag: remove_user_config_show_longdescription_always
-- @description: Benutzereinstellung für Langtext immer anzeigen entfernen (ist nun in den UserPrefs).
-- @depends:

DELETE FROM auth.user_config WHERE cfg_key LIKE 'show_longdescription_always';
