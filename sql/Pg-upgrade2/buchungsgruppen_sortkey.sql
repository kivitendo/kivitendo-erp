-- @tag: buchungsgruppen_sortkey
-- @description: Neue Spalte f&uuml;r Sortierreihenfolge der Buchungsgruppen
-- @depends: release_2_4_1
ALTER TABLE buchungsgruppen ADD COLUMN sortkey integer;
CREATE SEQUENCE tmp_counter;
UPDATE buchungsgruppen SET sortkey = nextval('tmp_counter');
DROP SEQUENCE tmp_counter;
ALTER TABLE buchungsgruppen ALTER COLUMN sortkey SET NOT NULL;
