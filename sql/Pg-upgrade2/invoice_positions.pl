# @tag: invoice_positions
# @description: Spalte für Positionen der Einträge in Rechnungen
# @depends: release_3_1_0
package SL::DBUpgrade2::invoice_positions;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my $query = qq|ALTER TABLE invoice ADD position INTEGER|;
  $self->db_query($query);


  $query = qq|SELECT * FROM invoice ORDER BY trans_id, id|;
  my $query2 = qq|UPDATE invoice SET position = ? WHERE id = ?|;

  my $sth = $self->dbh->prepare($query);
  my $sth2 = $self->dbh->prepare($query2);
  $sth->execute || $::form->dberror($query);

  # set new position field in order of ids, starting by one for each invoice
  my $last_invoice_id;
  my $position;
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    if ($ref->{trans_id} != $last_invoice_id) {
      $position = 1;
    } else {
      $position++;
    }
    $last_invoice_id = $ref->{trans_id};

    $sth2->execute($position, $ref->{id});
  }
  $sth->finish;
  $sth2->finish;

  $query = qq|ALTER TABLE invoice ALTER COLUMN position SET NOT NULL|;
  $self->db_query($query);

  return 1;
}

1;
