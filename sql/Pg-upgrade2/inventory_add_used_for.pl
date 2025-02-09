# @tag: inventory_add_used_for
# @description: benutzt für erzeugnis parts.id
# @depends: release_3_9_1 inventory_add_used_for_assembly

package SL::DBUpgrade2::inventory_add_used_for;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  # get the last 5500 trans ids with assemblies -> last 9 months CEOS
  my $query_all_assembled = qq|
      SELECT trans_id,parts_id FROM inventory
      LEFT JOIN parts p ON (p.id=parts_id)
      WHERE    trans_type_id= (SELECT id FROM transfer_type WHERE description='assembled')
      AND used_for_assembly_id is null
      ORDER by inventory.itime DESC
      LIMIT 5500
  |;

  my $refs = selectall_hashref_query($::form, $self->dbh, $query_all_assembled);

  my $query_add = qq|
    UPDATE inventory SET used_for_assembly_id = ?
    WHERE  trans_type_id =(select id from transfer_type where direction ='out' and description='used')
    AND trans_id = ?
  |;
  my $sth_add = $self->dbh->prepare($query_add);

  foreach my $ref (@$refs) {
    $sth_add->execute($ref->{parts_id}, $ref->{trans_id}) || $::form->dberror($query_add);
  }

  $sth_add->finish;

  return 1;
}

1;
