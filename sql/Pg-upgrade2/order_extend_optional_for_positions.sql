-- @tag: order_extend_optional_for_positions
-- @description: optionale Positionen in Angeboten/Aufträgen können inklusive oder nach Aufwand sein
-- @depends: linet_order_alternative_positions

ALTER TYPE position_optional_type ADD VALUE 'included';
ALTER TYPE position_optional_type ADD VALUE 'at_cost';
