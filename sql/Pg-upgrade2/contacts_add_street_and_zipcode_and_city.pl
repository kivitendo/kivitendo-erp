# @tag: contacts_add_street_and_zipcode_and_city
# @description: Spalten hinzuf&uuml;gen.
# @depends: release_2_7_0
package SL::DBUpgrade2::contacts_add_street_and_zipcode_and_city;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my @queries = (
    'ALTER TABLE contacts ADD COLUMN cp_street text;',
    'ALTER TABLE contacts ADD COLUMN cp_zipcode text;',
    'ALTER TABLE contacts ADD COLUMN cp_city text;',
  );

  $self->db_query($_, may_fail => 1) for @queries;

  return 1;
}

1;
