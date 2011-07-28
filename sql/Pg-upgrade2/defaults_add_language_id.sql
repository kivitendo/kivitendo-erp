-- @tag: defaults_add_language_id
-- @description: Id der Standardsprache in defaults speichern
-- @depends: release_2_6_2
-- @charset: utf-8
ALTER TABLE defaults ADD COLUMN language_id integer;
