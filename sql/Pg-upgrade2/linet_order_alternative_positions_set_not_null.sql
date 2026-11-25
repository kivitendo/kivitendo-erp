-- @tag: linet_order_alternative_positions_set_not_null
-- @description: LINET: optionale Positionen in Angeboten/Aufträgen können auch Alternativpositionen sein
-- @depends: linet_order_alternative_positions release_4_1_0

ALTER TABLE orderitems
  ALTER COLUMN optional SET NOT NULL;
