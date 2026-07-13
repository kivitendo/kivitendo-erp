-- @tag: defaults_add_inherit_assortment_price_from_master_data
-- @description: Sortimentspreis aus den Stammdaten in Angebots- / Auftragspositionen übernehmen
-- @depends: release_4_0_0
ALTER TABLE defaults ADD COLUMN inherit_assortment_price_from_master_data BOOLEAN NOT NULL default false;

