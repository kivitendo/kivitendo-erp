-- @tag: assortment_charge
-- @description: Sortimentsartikel erweitert, bestimmen ob Artikel berechnet werden soll
-- @depends: release_3_3_0 assortment_items

ALTER TABLE assortment_items ADD COLUMN charge BOOLEAN DEFAULT TRUE;
