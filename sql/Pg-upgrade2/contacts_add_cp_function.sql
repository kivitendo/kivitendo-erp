-- @tag: contacts_add_cp_function
-- @description: Feld 'Funktion/Position' zu Kontakten
-- @depends: release_3_0_0
-- @charset: utf-8
ALTER TABLE contacts ADD COLUMN cp_function text;
