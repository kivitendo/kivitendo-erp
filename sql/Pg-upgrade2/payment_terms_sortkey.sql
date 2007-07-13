-- @tag: payment_terms_sortkey
-- @description: Neue Spalte f&uuml;r Sortierreihenfolge der Zahlungskonditionen
-- @depends: release_2_4_1
ALTER TABLE payment_terms ADD COLUMN sortkey integer;
CREATE SEQUENCE tmp_counter;
UPDATE payment_terms SET sortkey = nextval('tmp_counter');
DROP SEQUENCE tmp_counter;
ALTER TABLE payment_terms ALTER COLUMN sortkey SET NOT NULL;
