-- @tag: defaults_order_warn_no_cusordnumber
-- @description: Mandantenkonfiguration: Warnung bei fehlender Kundenbestellnummer in Verkaufsaufträgen
-- @depends: release_3_5_8

ALTER TABLE defaults ADD COLUMN order_warn_no_cusordnumber BOOLEAN DEFAULT FALSE;
