# @tag: contacts_add_cp_position
# @description: Feld 'Funktion/Position' zu Kontakten
# @depends: release_3_0_0
# @charset: utf-8

package contacts_add_cp_position;
use strict;

die 'This script cannot be run from the command line.' if !$::form;

my $query = 'ALTER TABLE contacts ADD COLUMN cp_position VARCHAR(75)';

if (!$dbh->do($query)) {
  $dbh->rollback;
  $dbh->begin_work;
}

1;
