-- @tag: defaults_order_warn_no_deliverydate
-- @description: Mandantenkonfiguration: Warnung falls kein Liefertermin eingetragen wurden
-- @depends: release_3_5_2

ALTER TABLE defaults ADD COLUMN order_warn_no_deliverydate BOOLEAN DEFAULT TRUE;
