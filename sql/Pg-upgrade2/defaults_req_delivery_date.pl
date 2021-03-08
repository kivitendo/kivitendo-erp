# @tag: defaults_req_delivery_date
# @description: Einstellung ob Liefertermin oder Gültigkeitstermin überhaupt gesetzt werden soll
# @depends: release_3_5_6_1
package SL::DBUpgrade2::defaults_req_delivery_date;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN reqdate_on boolean DEFAULT true|);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN deliverydate_on boolean DEFAULT true|);
  return 1;
}

1;
