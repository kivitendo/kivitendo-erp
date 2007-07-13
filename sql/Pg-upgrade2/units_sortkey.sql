-- @tag: units_sortkey
-- @description: Neue Spalte f&uuml;r Sortierreihenfolge der Einheiten
-- @depends: release_2_4_1
ALTER TABLE units ADD COLUMN sortkey integer;
CREATE SEQUENCE tmp_counter;
UPDATE units SET sortkey = nextval('tmp_counter');
DROP SEQUENCE tmp_counter;
ALTER TABLE units ALTER COLUMN sortkey SET NOT NULL;
