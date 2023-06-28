-- @tag: add_parts_order_qty
-- @description: Bestellmenge für Artikel
-- @depends: release_3_8_0
-- @ignore: 0

ALTER TABLE parts ADD COLUMN
  order_qty numeric(15, 5) NOT NULL DEFAULT 0;
