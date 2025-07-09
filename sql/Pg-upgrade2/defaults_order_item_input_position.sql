-- @tag: defaults_order_item_input_position
-- @description: Mandantenkonfiguration: Position der Artikeleingabe in Aufträgen
-- @depends: release_3_9_1

ALTER TABLE defaults ADD COLUMN order_item_input_position INTEGER NOT NULL DEFAULT 0;
