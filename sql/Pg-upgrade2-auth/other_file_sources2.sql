-- @tag: other_file_sources2
-- @description: Neue Gruppenrechte für das Importieren von Scannern oder email auf freie Position
-- @depends: release_3_4_0 other_file_sources
update auth.master_rights set position='2680' where name='import_ap';
