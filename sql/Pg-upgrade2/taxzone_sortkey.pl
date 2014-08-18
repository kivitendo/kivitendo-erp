# @tag: taxzone_sortkey
# @description: Setzt eine neue Spalte sortkey in der Datenbank, um Steuerzonen sortierbar zu machen.
# @depends: taxzone_charts
package SL::DBUpgrade2::taxzone_sortkey;

use strict;
use utf8;

use SL::DB::Manager::TaxZone;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my $query = qq|ALTER TABLE tax_zones ADD COLUMN sortkey INTEGER|;
  $self->db_query($query);

  my $sortkey = 1;
  $query = qq|SELECT * FROM tax_zones ORDER BY id|;

  my $sth = $self->dbh->prepare($query);
  $sth->execute || $::form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    $self->db_query(qq|UPDATE tax_zones SET sortkey = $sortkey WHERE id = | . $ref->{id});
    $sortkey++;
  }
  $sth->finish;

  $query = qq|ALTER TABLE tax_zones ALTER COLUMN sortkey SET NOT NULL|;
  $self->db_query($query);

  return 1;
} # end run

1;
