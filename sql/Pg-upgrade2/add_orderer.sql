-- @tag: add_orderer
-- @description: Neue Spalte Besteller in Angebots- und Lieferscheinpositionen
-- @depends: release_3_8_0
-- @ignore: 0

ALTER TABLE orderitems ADD COLUMN orderer_id INTEGER REFERENCES employee(id);
ALTER TABLE delivery_order_items ADD COLUMN orderer_id INTEGER REFERENCES employee(id);
