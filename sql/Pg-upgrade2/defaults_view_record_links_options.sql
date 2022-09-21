-- @tag: defaults_view_record_links_options
-- @description: Mandantenkonfiguration: Optionen für Sichtweise von record links immer vom Auftrag
-- @depends: release_3_7_0

ALTER TABLE defaults ADD COLUMN record_links_from_order_with_myself     BOOLEAN DEFAULT FALSE;
ALTER TABLE defaults ADD COLUMN record_links_from_order_with_quotations BOOLEAN DEFAULT FALSE;
