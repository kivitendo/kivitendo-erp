-- @tag: defaults_drop_delivery_plan_config
-- @description: Die 3.1er Erweiterung des Lieferplans ist mittlerweile in einem eigenen Bericht (Lieferwertbericht) und muss nicht extra in den defaults konfiguriert werden
-- @depends: release_3_2_0
ALTER TABLE defaults DROP COLUMN delivery_plan_show_value_of_goods;

