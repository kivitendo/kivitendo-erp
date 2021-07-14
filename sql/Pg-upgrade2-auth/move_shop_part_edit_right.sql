-- @tag: move_shop_part_edit_right
-- @description: Recht zum Editieren von Shop-Artikeln verschieben
-- @depends: release_3_5_7

UPDATE auth.master_rights SET position = 580 WHERE position = 550 AND name = 'shop_part_edit';
