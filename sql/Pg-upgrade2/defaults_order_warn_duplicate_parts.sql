-- @tag: defaults_order_warn_duplicate_parts
-- @description: Mandantenkonfiguration: Warnung bei doppelten Artikeln in Aufträgen
-- @depends: release_3_3_0

ALTER TABLE defaults ADD COLUMN order_warn_duplicate_parts BOOLEAN DEFAULT TRUE;
