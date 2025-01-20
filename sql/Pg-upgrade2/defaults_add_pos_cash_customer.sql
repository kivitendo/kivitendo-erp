-- @tag: defaults_add_pos_cash_customer
-- @description: Mandantenkonfiguration für Bargeldkunde der Kasse
-- @depends: release_3_9_0

ALTER TABLE defaults ADD COLUMN pos_cash_customer_id INTEGER references customer(id);
