-- @tag: orderitems_optional
-- @description: Optionale Artikel im Angebot und Auftrag
-- @depends: release_3_5_6_1
ALTER TABLE orderitems ADD COLUMN optional BOOLEAN default FALSE;

