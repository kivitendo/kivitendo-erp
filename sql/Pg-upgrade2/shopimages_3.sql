-- @tag:shopimages_3
-- @description: Neue Spalte object_id um eine group_by Klausel zu haben für act_as_list
-- @depends: release_3_5_0 files shop_parts shopimages
-- @ignore: 0

ALTER TABLE shop_images ADD COLUMN object_id text NOT NULL;
