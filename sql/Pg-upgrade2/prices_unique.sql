-- @tag: prices_unique
-- @description: DB-Constraint - nur ein Preis pro Artikel pro Preisgruppe
-- @depends: release_3_4_1

-- it would be easier to just have a composite primary key on parts_id and
-- pricegroup_id, but that would need some code refactoring
ALTER TABLE prices ADD CONSTRAINT parts_id_pricegroup_id_unique UNIQUE (parts_id, pricegroup_id);
ALTER TABLE prices ALTER COLUMN parts_id SET NOT NULL;
ALTER TABLE prices ALTER COLUMN pricegroup_id SET NOT NULL;
