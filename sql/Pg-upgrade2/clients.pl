# @tag: clients
# @description: Mandanten
# @depends: release_3_0_0
package SL::DBUpgrade2::clients;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my @queries = (
    qq|ALTER TABLE defaults ADD COLUMN company          TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN address          TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN taxnumber        TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN co_ustid         TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN duns             TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN sepa_creditor_id TEXT|,
    qq|ALTER TABLE defaults ADD COLUMN templates        TEXT|,
  );

  $self->db_query($_) for @queries;

  return 1;
}

1;
