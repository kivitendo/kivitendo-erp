-- @tag: defaults_order_controller
-- @description: Mandantenkonfiguration: Order-Controller auf aktiv setzen
-- @depends: release_3_5_8
UPDATE defaults SET feature_experimental_order = TRUE;
