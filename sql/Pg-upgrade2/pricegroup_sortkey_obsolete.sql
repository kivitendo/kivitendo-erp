-- @tag: pricegroup_sortkey_obsolete
-- @description: Sortierreihenfolge und ungültig für Preisgruppen
-- @depends: release_3_4_1
-- @ignore: 0

ALTER TABLE pricegroup ADD COLUMN obsolete BOOLEAN DEFAULT FALSE;
ALTER TABLE pricegroup ADD COLUMN sortkey INTEGER;

CREATE SEQUENCE tmp_counter;
UPDATE pricegroup SET sortkey = nextval('tmp_counter');
DROP SEQUENCE tmp_counter;
ALTER TABLE pricegroup ALTER COLUMN sortkey SET NOT NULL;
