-- @tag: other_file_sources
-- @description: Neue Gruppenrechte für das Importieren von Scannern oder email
-- @depends: release_3_4_0 master_rights_position_gaps
-- @locales: Import AP from Scanner or Email
-- @locales: Import AR from Scanner or Email
INSERT INTO auth.master_rights (position, name, description) VALUES (2050, 'import_ar', 'Import AR from Scanner or Email');
INSERT INTO auth.master_rights (position, name, description) VALUES (2650, 'import_ap', 'Import AP from Scanner or Email');
