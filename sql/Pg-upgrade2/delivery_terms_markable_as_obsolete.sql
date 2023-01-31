-- @tag: delivery_terms_markable_as_obsolete
-- @description: Lieferbedingungenals ungültig markierbar
-- @depends: release_3_7_0
ALTER TABLE delivery_terms
ADD COLUMN obsolete BOOLEAN NOT NULL DEFAULT FALSE;
