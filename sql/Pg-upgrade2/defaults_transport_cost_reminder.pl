# @tag: defaults_transport_cost_reminder
# @description: Artikelname der beim Auftrag auf Vorhandensein überprüft wird (Versandkostenerinnerung).
# @depends: release_3_1_0
package SL::DBUpgrade2::defaults_transport_cost_reminder;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN transport_cost_reminder_article_number text|);
  return 1;
}

1;
