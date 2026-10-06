-- @tag: linet_order_alternative_positions
-- @description: LINET: optionale Positionen in Angboten/Aufträgen können auch Alternativpositionen sein
-- @depends: linet_oe_position_type release_4_1_0

-- Umstellung vorhandene offizielle Struktur auf enum
CREATE TYPE position_optional_type AS ENUM ('regular', 'alternative', 'optional');
ALTER TABLE orderitems ADD COLUMN tmp_optional position_optional_type DEFAULT 'regular';
UPDATE orderitems SET tmp_optional = 'optional' WHERE optional;

-- Umstellung LINET-Struktur auf neue enum
UPDATE orderitems
SET tmp_optional =
  CASE WHEN item_type = 'optional'::record_item_type
    THEN 'optional'::position_optional_type
    ELSE 'alternative'::position_optional_type
  END
WHERE item_type IN ('optional', 'alternative');

-- Finale Anpassung: Entfernen alter Spalten, Umbenennung temporärer Spalte
ALTER TABLE orderitems
  DROP COLUMN optional,
  DROP COLUMN item_type;
ALTER TABLE orderitems
  RENAME COLUMN tmp_optional TO optional;
