# @tag: record_links_remove_to_quotation
# @description: Verknüpfte Positionen mit Ziel Angebot und dazugehörige Belegverknüpfung entfernen, wenn Quelle Angebot oder Auftrag.
# @depends: release_3_6_0
package SL::DBUpgrade2::record_links_remove_to_quotation;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  my $query = qq|SELECT record_links.id AS rl_id, from_oe.id AS from_oe_id, to_oe.id AS to_oe_id FROM record_links
                   LEFT JOIN orderitems from_oi ON (from_oi.id = from_id)
                   LEFT JOIN orderitems to_oi   ON (to_oi.id   = to_id)
                   LEFT JOIN oe         from_oe ON (from_oe.id = from_oi.trans_id)
                   LEFT JOIN oe         to_oe   ON (to_oe.id   = to_oi.trans_id)
                 WHERE from_table = 'orderitems'
                   AND to_table   = 'orderitems'
                   AND to_oe.quotation IS TRUE|;

  my $refs = selectall_hashref_query($::form, $self->dbh, $query);

  my $query_delete_oi_links = qq|
    DELETE FROM record_links WHERE id = ?;
  |;
  my $sth_delete_oi_links = $self->dbh->prepare($query_delete_oi_links);

  my $query_delete_oe_links = qq|
    DELETE FROM record_links WHERE from_table = 'oe' AND to_table = 'oe' AND from_id = ? AND to_id = ?;
  |;
  my $sth_delete_oe_links = $self->dbh->prepare($query_delete_oe_links);

  my %oe_links;
  foreach my $ref (@$refs) {
    $sth_delete_oi_links->execute($ref->{rl_id}) || $::form->dberror($query_delete_oi_links);
    $oe_links{$ref->{from_oe_id} . ':' . $ref->{to_oe_id}} = 1;
  }

  for my $from_to (keys %oe_links) {
    my ($from_oe_id, $to_oe_id) = split ':', $from_to;
    $sth_delete_oe_links->execute($from_oe_id, $to_oe_id) || $::form->dberror($query_delete_oe_links);
  }

  return 1;
}

1;
