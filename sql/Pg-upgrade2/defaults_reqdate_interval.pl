# @tag: defaults_reqdate_interval
# @description: Einstellen der Angebotsgültigkeit per Intervall (z.B.: +28 Tage)
# @depends: release_3_1_0
package SL::DBUpgrade2::defaults_reqdate_interval;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN reqdate_interval integer DEFAULT 0|);
  return 1;
}

1;
