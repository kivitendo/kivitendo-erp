-- @tag: record_items_update_base_qty
-- @description: Basis-Menge (bezogen auf Artikeleinheit) neu berechnen, wo fehlerhaft
-- @depends: delivery_orders units_id
-- @ignore: 0

-- collect all base factors for all units
CREATE TEMPORARY TABLE temp_unit_base_factors (
  name        character varying(20),
  base_factor numeric(20,5)
);

INSERT INTO temp_unit_base_factors (
  SELECT
    all_units.name,
    b.base_factor
  FROM units all_units
  CROSS JOIN LATERAL (
    WITH RECURSIVE base_units AS (
        SELECT u.name, u.base_unit,
          ( CASE WHEN u.base_unit IS NULL THEN 1.0 ELSE 1.0 * u.factor END ) AS base_factor,
          u.id FROM units u
          WHERE u.name = all_units.name
      UNION ALL
        SELECT bu.name, u.base_unit, u.factor * bu.base_factor AS base_factor, u.id FROM base_units bu, units u
          WHERE u.name = bu.base_unit AND u.base_unit IS NOT NULL
    ) SEARCH DEPTH FIRST BY id SET ordercol
    SELECT base_factor FROM base_units ORDER BY ordercol DESC LIMIT 1
  ) b
);

-- update base_qty where not set or wrong

-- orderitems
UPDATE orderitems i
   SET base_qty = i.qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = i.unit)/(SELECT base_factor FROM temp_unit_base_factors WHERE name = (SELECT unit FROM parts WHERE parts.id = i.parts_id))
 WHERE base_qty IS NULL OR
   ABS(i.qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = i.unit) - i.base_qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = (SELECT unit FROM parts WHERE parts.id = i.parts_id))) > 1e-4;

-- delivery_order_items
UPDATE delivery_order_items i
   SET base_qty = i.qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = i.unit)/(SELECT base_factor FROM temp_unit_base_factors WHERE name = (SELECT unit FROM parts WHERE parts.id = i.parts_id))
 WHERE base_qty IS NULL OR
   ABS(i.qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = i.unit) - i.base_qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = (SELECT unit FROM parts WHERE parts.id = i.parts_id))) > 1e-4;

-- invoice
UPDATE invoice i
   SET base_qty = i.qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = i.unit)/(SELECT base_factor FROM temp_unit_base_factors WHERE name = (SELECT unit FROM parts WHERE parts.id = i.parts_id))
 WHERE base_qty IS NULL OR
   ABS(i.qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = i.unit) - i.base_qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = (SELECT unit FROM parts WHERE parts.id = i.parts_id))) > 1e-4;

-- reclamation_items
-- there is no need to handle reclamation_items, because the used the PTC from
-- the beginning on and the PTC sets the base_qty
--
-- UPDATE reclamation_items i
--    SET base_qty = i.qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = i.unit)/(SELECT base_factor FROM temp_unit_base_factors WHERE name = (SELECT unit FROM parts WHERE parts.id = i.parts_id))
--  WHERE base_qty IS NULL OR
--    ABS(i.qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = i.unit) - i.base_qty*(SELECT base_factor FROM temp_unit_base_factors WHERE name = (SELECT unit FROM parts WHERE parts.id = i.parts_id))) > 1e-4;
