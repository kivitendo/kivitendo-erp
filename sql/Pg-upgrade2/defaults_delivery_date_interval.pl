# @tag: defaults_delivery_date_interval
# @description: Einstellen des Liefertermins für Aufträge per Intervall (z.B.: +28 Tage)
# @depends: release_3_5_3
package SL::DBUpgrade2::defaults_delivery_date_interval;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN delivery_date_interval integer DEFAULT 0|);
  return 1;
}

1;
