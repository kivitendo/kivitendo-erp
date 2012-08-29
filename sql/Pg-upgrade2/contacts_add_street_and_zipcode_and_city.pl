# @tag: contacts_add_street_and_zipcode_and_city
# @description: Spalten hinzuf&uuml;gen.
# @depends: release_2_7_0
# @charset: utf-8

use utf8;
use strict;

my @queries = (
  'ALTER TABLE contacts ADD COLUMN cp_street text;',
  'ALTER TABLE contacts ADD COLUMN cp_zipcode text;',
  'ALTER TABLE contacts ADD COLUMN cp_city text;',
);

foreach my $query (@queries) {
  if ( $dbh->do($query) ) {
    next;
  }

  $dbh->rollback();
  $dbh->begin_work();
}

return 1;
