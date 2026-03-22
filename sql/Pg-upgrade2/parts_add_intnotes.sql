-- @tag: parts_add_intnotes
-- @description: Neues Feld für interne Bemerkungen
-- @depends: release_4_0_0
ALTER TABLE parts ADD COLUMN intnotes TEXT;
