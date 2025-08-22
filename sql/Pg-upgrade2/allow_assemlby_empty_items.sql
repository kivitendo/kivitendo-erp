-- @tag: allow_assemlby_empty_items
-- @description: Erzeugnis fertigen erlaubt auch Erzeugnisbestandteile mit Menge 0
-- @depends: release_3_9_1
ALTER TABLE defaults ADD COLUMN produce_assembly_allow_empty_items boolean DEFAULT false;
