-- @tag: displayable_name_prefs_defaults
-- @description: Setzen der Default-Einstellungen für einstellbare Picker-Anzeigen
-- @depends: user_preferences

INSERT INTO user_preferences (login, namespace, version, key, value)
  SELECT '#default#','DisplayableName','0.00000','SL::DB::Customer','<%customernumber%> <%name%>'
    WHERE NOT EXISTS (SELECT id FROM user_preferences WHERE login LIKE '#default#' AND namespace LIKE 'DisplayableName' AND version = 0.00000 AND key LIKE 'SL::DB::Customer');
INSERT INTO user_preferences (login, namespace, version, key, value)
  SELECT '#default#','DisplayableName','0.00000','SL::DB::Vendor','<%vendornumber%> <%name%>'
    WHERE NOT EXISTS (SELECT id FROM user_preferences WHERE login LIKE '#default#' AND namespace LIKE 'DisplayableName' AND version = 0.00000 AND key LIKE 'SL::DB::Vendor');
INSERT INTO user_preferences (login, namespace, version, key, value)
  SELECT '#default#','DisplayableName','0.00000','SL::DB::Part','<%partnumber%> <%description%>'
    WHERE NOT EXISTS (SELECT id FROM user_preferences WHERE login LIKE '#default#' AND namespace LIKE 'DisplayableName' AND version = 0.00000 AND key LIKE 'SL::DB::Part');
