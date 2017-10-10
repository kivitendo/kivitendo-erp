# @tag: orderitems_delivery_order_items_positions
# @description: Spalte für Positionen der Einträge in Angeboten/Auftträgen und Lieferscheinen.
# @depends: release_3_1_0
package SL::DBUpgrade2::orderitems_delivery_order_items_positions;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my %order_id_cols = (
    orderitems           => 'trans_id',
    delivery_order_items => 'delivery_order_id',
  );

  foreach my $table ( keys %order_id_cols ) {

    my $query = qq|ALTER TABLE $table ADD position INTEGER|;
    $self->db_query($query);


    my $order_id_col = $order_id_cols{ $table };
    $query = qq|SELECT * FROM $table ORDER BY $order_id_col, id|;
    my $query2 = qq|UPDATE $table SET position = ? WHERE id = ?|;

    my $sth = $self->dbh->prepare($query);
    my $sth2 = $self->dbh->prepare($query2);
    $sth->execute || $::form->dberror($query);

    # set new position field in order of ids, starting by one for each order
    my $last_order_id;
    my $position;
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      if ($ref->{ $order_id_col } != $last_order_id) {
        $position = 1;
      } else {
        $position++;
      }
      $last_order_id = $ref->{ $order_id_col };

      $sth2->execute($position, $ref->{id});
    }
    $sth->finish;
    $sth2->finish;


    $query = qq|ALTER TABLE $table ALTER COLUMN position SET NOT NULL|;
    $self->db_query($query);
  }

  return 1;
}

1;
