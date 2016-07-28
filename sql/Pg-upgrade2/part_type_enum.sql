-- @tag: part_type_enum
-- @description: enums
-- @depends: release_3_4_1

CREATE TYPE part_type_enum AS ENUM ('part', 'service', 'assembly', 'assortment');
ALTER TABLE parts ADD COLUMN part_type part_type_enum;

UPDATE parts SET part_type = 'assembly' WHERE assembly IS TRUE;
UPDATE parts SET part_type = 'service'  WHERE inventory_accno_id IS NULL and part_type IS NULL;
UPDATE parts SET part_type = 'part'     WHERE assembly IS FALSE AND inventory_accno_id IS NOT NULL AND part_type IS NULL;

-- don't set a default for now to help with finding bugs where no part_type is passed
ALTER TABLE parts ALTER COLUMN part_type SET NOT NULL;

CREATE OR REPLACE FUNCTION update_purchase_price() RETURNS trigger AS '
BEGIN
  if tg_op = ''DELETE'' THEN
    UPDATE parts SET lastcost = COALESCE((select sum ((a.qty * (p.lastcost / COALESCE(pf.factor,
    1)))) as summe from assembly a left join parts p on (p.id = a.parts_id)
    LEFT JOIN price_factors pf on (p.price_factor_id = pf.id) where a.id = parts.id),0)
    WHERE part_type = ''assembly'' and id = old.id;
    return old; -- old ist eine referenz auf die geloeschte reihe
  ELSE
    UPDATE parts SET lastcost = COALESCE((select sum ((a.qty * (p.lastcost / COALESCE(pf.factor,
    1)))) as summe from assembly a left join parts p on (p.id = a.parts_id)
    LEFT JOIN price_factors pf on (p.price_factor_id = pf.id)
    WHERE a.id = parts.id),0) where part_type = ''assembly'' and id = new.id;
    return new; -- entsprechend new, wird wahrscheinlich benoetigt, um den korrekten Eintrag
                -- zu filtern bzw. dann zu aktualisieren
  END IF;
END;
' LANGUAGE plpgsql;
