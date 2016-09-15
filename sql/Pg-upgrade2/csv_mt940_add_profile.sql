-- @tag: csv_mt940_add_profile
-- @description: Default Profile zum Importieren von mt940
-- @depends: csv_import_profiles_2

INSERT INTO csv_import_profiles (name,type,is_default,login) VALUES ('MT940','bank_transactions','t','default');
INSERT INTO csv_import_profile_settings (csv_import_profile_id,key,value) VALUES ((SELECT id FROM csv_import_profiles WHERE name='MT940' AND login='default'),'charset','UTF-8');
INSERT INTO csv_import_profile_settings (csv_import_profile_id,key,value) VALUES ((SELECT id FROM csv_import_profiles WHERE name='MT940' AND login='default'),'full_preview','0');
INSERT INTO csv_import_profile_settings (csv_import_profile_id,key,value) VALUES ((SELECT id FROM csv_import_profiles WHERE name='MT940' AND login='default'),'update_policy','skip');
INSERT INTO csv_import_profile_settings (csv_import_profile_id,key,value) VALUES ((SELECT id FROM csv_import_profiles WHERE name='MT940' AND login='default'),'numberformat','1000.00');
INSERT INTO csv_import_profile_settings (csv_import_profile_id,key,value) VALUES ((SELECT id FROM csv_import_profiles WHERE name='MT940' AND login='default'),'sep_char',';');
INSERT INTO csv_import_profile_settings (csv_import_profile_id,key,value) VALUES ((SELECT id FROM csv_import_profiles WHERE name='MT940' AND login='default'),'quote_char','"');
INSERT INTO csv_import_profile_settings (csv_import_profile_id,key,value) VALUES ((SELECT id FROM csv_import_profiles WHERE name='MT940' AND login='default'),'escape_char','"');
INSERT INTO csv_import_profile_settings (csv_import_profile_id,key,value) VALUES ((SELECT id FROM csv_import_profiles WHERE name='MT940' AND login='default'),'json_mappings','[]');
INSERT INTO csv_import_profile_settings (csv_import_profile_id,key,value) VALUES ((SELECT id FROM csv_import_profiles WHERE name='MT940' AND login='default'),'duplicates','no_check');
INSERT INTO csv_import_profile_settings (csv_import_profile_id,key,value) VALUES ((SELECT id FROM csv_import_profiles WHERE name='MT940' AND login='default'),'dont_edit_profile','1');

