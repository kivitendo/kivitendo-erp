# @tag: prices_delete_cascade
# @description: Preisgruppenpreise Löschen wenn Artikel gelöscht wird
# @depends: release_3_4_1

# delete price entries if part is deleted

package SL::DBUpgrade2::prices_delete_cascade;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->drop_constraints(table => "prices");

  my $query = <<SQL;
    ALTER TABLE prices
    ADD CONSTRAINT prices_pricegroup_id_fkey FOREIGN KEY (pricegroup_id) REFERENCES pricegroup(id) ON DELETE CASCADE,
    ADD CONSTRAINT prices_parts_id_fkey      FOREIGN KEY (parts_id)      REFERENCES parts(id)      ON DELETE CASCADE
SQL

  $self->db_query($query);

  return 1;
}

1;
