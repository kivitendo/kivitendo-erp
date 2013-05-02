# @tag: rm_whitespaces
# @description: Entfernt mögliche Leerzeichen am Anfang und Ende jeder Währung
# @depends: release_3_0_0

package SL::DBUpgrade2::rm_whitespaces;

use parent qw(SL::DBUpgrade2::Base);

use utf8;
use strict;

sub run {
  my ($self) = @_;
  my $query = qq|UPDATE ar SET curr = RTRIM(LTRIM(curr))|;
  $self->db_query($query);
  $query = qq|UPDATE ap SET curr = RTRIM(LTRIM(curr))|;
  $self->db_query($query);
  $query = qq|UPDATE oe SET curr = RTRIM(LTRIM(curr))|;
  $self->db_query($query);
  $query = qq|UPDATE customer SET curr = RTRIM(LTRIM(curr))|;
  $self->db_query($query);
  $query = qq|UPDATE delivery_orders SET curr = RTRIM(LTRIM(curr))|;
  $self->db_query($query);
  $query = qq|UPDATE exchangerate SET curr = RTRIM(LTRIM(curr))|;
  $self->db_query($query);
  $query = qq|UPDATE vendor SET curr = RTRIM(LTRIM(curr))|;
  $self->db_query($query);

  $query = qq|SELECT curr FROM defaults|;
  my ($curr)     = $self->dbh->selectrow_array($query);

  $curr  =~ s/ //g;

  $query = qq|UPDATE defaults SET curr = '$curr'|;
  $self->db_query($query);
  return 1;
};

1;
