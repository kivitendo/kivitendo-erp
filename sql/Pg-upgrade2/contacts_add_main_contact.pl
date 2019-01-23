# @tag: contacts_add_main_contact
# @description: Feld 'Hauptansprechpartner' für Kontakte
# @depends: release_3_5_3
package SL::DBUpgrade2::contacts_add_main_contact;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->db_query('ALTER TABLE contacts ADD COLUMN cp_main boolean DEFAULT false', may_fail => 1);
  $self->db_query("UPDATE contacts set cp_main='false'");

  return 1;
}

1;
