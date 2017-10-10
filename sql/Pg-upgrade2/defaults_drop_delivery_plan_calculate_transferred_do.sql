-- @tag: defaults_drop_delivery_plan_calculate_transferred_do
-- @description: Entferne Einstellung für Lieferplan, nur ausgelagerte Lieferscheine zu berücksichtigen
-- @depends: defaults_add_delivery_plan_config

ALTER TABLE defaults DROP COLUMN delivery_plan_calculate_transferred_do;
