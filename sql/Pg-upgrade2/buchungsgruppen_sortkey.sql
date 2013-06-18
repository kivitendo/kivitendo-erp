-- @tag: buchungsgruppen_sortkey
-- @description: Neue Spalte für Sortierreihenfolge der Buchungsgruppen
-- @depends: release_2_4_1
ALTER TABLE buchungsgruppen ADD COLUMN sortkey integer;
CREATE SEQUENCE tmp_counter;
UPDATE buchungsgruppen SET sortkey = nextval('tmp_counter');
DROP SEQUENCE tmp_counter;
ALTER TABLE buchungsgruppen ALTER COLUMN sortkey SET NOT NULL;

-- 'Standard 16%/19%' als ersten Eintrag. Der ermäßigte Umsatzsteuersatz wird seltener verwendet.
UPDATE buchungsgruppen SET sortkey=2  WHERE description='Standard 7%';
UPDATE buchungsgruppen SET sortkey=1  WHERE description='Standard 16%/19%';
