-- @tag: defaults_add_prices_always_free
-- @description: Mandantenkonfiguration, um den beim Hinzufügen von Positionen den Preis immer frei (editierbar) zu belassen
-- @depends: release_4_0_0

ALTER TABLE defaults ADD COLUMN prices_always_free BOOLEAN default false;
