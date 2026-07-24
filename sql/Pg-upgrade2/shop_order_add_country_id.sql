-- @tag: shop_orders_add_country_id
-- @description: Hinzufügen der Spalte country_id wg neuerem Ländermodul
-- @depends: release_4_0_0 countries_phase_2
-- @ignore: 0

ALTER TABLE shop_orders ADD COLUMN billing_country_id INTEGER REFERENCES countries(id);
ALTER TABLE shop_orders ADD COLUMN customer_country_id INTEGER REFERENCES countries(id);
ALTER TABLE shop_orders ADD COLUMN delivery_country_id INTEGER REFERENCES countries(id);

