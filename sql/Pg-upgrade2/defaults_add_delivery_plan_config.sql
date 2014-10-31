-- @tag: defaults_add_delivery_plan_config
-- @description: Konfigurative Erweiterungen für den Lieferplan (od)
-- @depends: release_3_1_0
ALTER TABLE defaults ADD COLUMN delivery_plan_show_value_of_goods boolean NOT NULL DEFAULT FALSE;
ALTER TABLE defaults ADD COLUMN delivery_plan_calculate_transferred_do boolean NOT NULL DEFAULT FALSE;

