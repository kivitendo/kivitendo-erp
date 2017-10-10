-- @tag: bankaccounts_sortkey_and_obsolete
-- @description: Bankkonto - Sortierreihenfolge und Ungültig
-- @depends: release_3_2_0

-- default false needed so that get_all_sorted( query => [ obsolete => 0 ] ) works
ALTER TABLE bank_accounts ADD COLUMN obsolete BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE bank_accounts ADD COLUMN sortkey INTEGER;
CREATE SEQUENCE tmp_counter;
UPDATE bank_accounts SET sortkey = nextval('tmp_counter');
DROP SEQUENCE tmp_counter;
ALTER TABLE bank_accounts ALTER COLUMN sortkey SET NOT NULL;
