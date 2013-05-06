# @tag: rm_whitespaces
# @description: Entfernt mögliche Leerzeichen am Anfang und Ende jeder Währung
# @depends: release_3_0_0

package SL::DBUpgrade2::rm_whitespaces;

use parent qw(SL::DBUpgrade2::Base);

use utf8;
use strict;

sub run {
  my ($self) = @_;

  my $query;

  foreach my $table (qw(ar ap oe customer delivery_orders exchangerate vendor)){
    $self->db_query(qq|UPDATE ${table} SET curr=BTRIM(curr)|)
  }

  $query = qq|SELECT curr FROM defaults|;
  my ($curr)     = $self->dbh->selectrow_array($query);

  $curr  =~ s/ //g;

  $query = qq|UPDATE defaults SET curr = '$curr'|;
  $self->db_query($query);
  return 1;
};

1;
