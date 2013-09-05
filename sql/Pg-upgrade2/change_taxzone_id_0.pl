# @tag: change_taxzone_id_0
# @description: Verändert die id von 0 auf einen anderen Wert größer 0 in tax_zones, wenn es so einen Eintrag gibt.
# @depends: convert_taxzone taxzone_default_id taxzone_sortkey
package SL::DBUpgrade2::change_taxzone_id_0;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my $query = qq|SELECT id FROM tax_zones ORDER BY id DESC|;
  my ($id) = $self->dbh->selectrow_array($query);
  $id++;

  $query = qq|SELECT * FROM tax_zones WHERE id=0|;
  my $sth = $self->dbh->prepare($query);
  $sth->execute || $::form->dberror($query);

  my $ref = $sth->fetchrow_hashref("NAME_lc");

  $query = qq|INSERT INTO tax_zones (id, description, sortkey) VALUES (?,?,?)|;
  $self->db_query($query, bind => [ $id, $ref->{description}, $ref->{sortkey} ]);

  $query = qq|UPDATE taxzone_charts SET taxzone_id=$id WHERE taxzone_id=0|;
  $self->db_query($query);

  $sth->finish;

  $query = qq|DELETE FROM tax_zones WHERE id=0|;
  $self->db_query($query);

  return 1;
} # end run

1;
