-- @tag: partsgroup_sortkey_obsolete
-- @description: Sortierreihenfolge und ungültig für Warengruppen
-- @depends: release_3_4_1
-- @ignore: 0

ALTER TABLE partsgroup ADD COLUMN obsolete BOOLEAN DEFAULT FALSE;
ALTER TABLE partsgroup ADD COLUMN sortkey INTEGER;

CREATE SEQUENCE tmp_counter;
UPDATE partsgroup SET sortkey = nextval('tmp_counter');
DROP SEQUENCE tmp_counter;
ALTER TABLE partsgroup ALTER COLUMN sortkey SET NOT NULL;
