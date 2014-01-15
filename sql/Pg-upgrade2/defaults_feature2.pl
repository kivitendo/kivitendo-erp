# @tag: defaults_feature2
# @description: Normalisieren von vc-Namen, als auch part.notes und part.descriptions als Feature konfigurierbar machen
# @depends: release_3_0_0
package SL::DBUpgrade2::defaults_feature2;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN normalize_vc_names  boolean DEFAULT true|);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN normalize_part_descriptions  boolean DEFAULT true|);
  return 1;
}

1;
