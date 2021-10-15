-- @tag: defaults_view_record_links
-- @description: Mandantenkonfiguration: Sichtweise für record links immer vom Auftrag
-- @depends: release_3_5_8

ALTER TABLE defaults ADD COLUMN always_record_links_from_order BOOLEAN DEFAULT FALSE;
