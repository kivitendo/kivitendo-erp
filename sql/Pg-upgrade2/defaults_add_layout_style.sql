-- @tag: defaults_add_layout_style
-- @description: Mandantenkonfiguration für erzwungenen Layout-Stil (Desktop oder Mobil)
-- @depends: release_3_8_0

ALTER TABLE defaults ADD COLUMN layout_style TEXT;
