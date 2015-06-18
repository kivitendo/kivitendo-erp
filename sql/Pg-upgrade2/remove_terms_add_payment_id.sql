-- @tag: remove_terms_add_payment_id
-- @description: In betroffenen Tabellen die veraltete Spalte »terms« löschen und dort, wo sie fehlt, payment_id ergänzen
-- @depends: release_3_2_0

ALTER TABLE delivery_orders ADD COLUMN payment_id INTEGER;
ALTER TABLE delivery_orders ADD FOREIGN KEY (payment_id) REFERENCES payment_terms (id);

UPDATE delivery_orders
SET payment_id = (
  SELECT oe.payment_id
  FROM record_links rl
  LEFT JOIN oe ON rl.from_id = oe.id
  WHERE (rl.from_table = 'oe')
    AND (rl.to_table   = 'delivery_orders')
    AND (rl.to_id      = delivery_orders.id)
  ORDER BY rl.itime DESC
  LIMIT 1
);

ALTER TABLE ar              DROP COLUMN terms;
ALTER TABLE customer        DROP COLUMN terms;
ALTER TABLE delivery_orders DROP COLUMN terms;
ALTER TABLE vendor          DROP COLUMN terms;
