-- @tag: drop_shipped_qty_config
-- @description: Verwaiste Optionen löschen
-- @depends: release_3_5_7

ALTER TABLE defaults DROP COLUMN shipped_qty_fill_up;
ALTER TABLE defaults DROP COLUMN shipped_qty_item_identity_fields;


