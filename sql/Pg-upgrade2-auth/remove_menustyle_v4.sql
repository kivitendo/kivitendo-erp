-- @tag: remove_menustyle_v4
-- @description: Menütyp "CSS (oben, neu)" wurde entfernt; also durch v3 ersetzen
-- @depends:
UPDATE auth.user_config
SET cfg_value = 'v3'
WHERE ((cfg_key   = 'menustyle')
  AND  (cfg_value = 'v4'));
