-- @tag: defaults_add_quick_search_modules
-- @description: Mandantenkonfiguration für Schnellsuche
-- @depends: release_3_4_0

ALTER TABLE defaults ADD COLUMN quick_search_modules TEXT[];

UPDATE defaults SET quick_search_modules = '{"contact","gl_transaction"}';
