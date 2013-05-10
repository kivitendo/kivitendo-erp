# @tag: contacts_add_cp_position
# @description: Feld 'Funktion/Position' zu Kontakten
# @depends: release_3_0_0
package SL::DBUpgrade2::contacts_add_cp_position;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->db_query('ALTER TABLE contacts ADD COLUMN cp_position VARCHAR(75)', may_fail => 1);

  return 1;
}

1;
