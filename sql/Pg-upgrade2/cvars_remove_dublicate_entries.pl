# @tag: cvars_remove_duplicate_entries
# @description: Doppelte Einträge für gleiche benutzerdefinierte Variablen entfernen (behalte den Neusten).
# @depends: release_3_4_1

package SL::DBUpgrade2::cvars_remove_duplicate_entries;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  # get all duplicates
  my $query_all_dups = qq|
    SELECT trans_id, config_id, sub_module FROM custom_variables
      GROUP BY trans_id, config_id, sub_module
      HAVING COUNT(*) > 1
  |;

  my $refs = selectall_hashref_query($::form, $self->dbh, $query_all_dups);

  # remove all but the newest one (order by itime descending)
  my $query_delete = qq|
    DELETE FROM custom_variables WHERE id = ?;
  |;
  my $sth_delete = $self->dbh->prepare($query_delete);

  my $query_all_but_newest = qq|
      SELECT id FROM custom_variables WHERE trans_id = ? AND config_id = ? AND sub_module = ? ORDER BY itime DESC OFFSET 1
  |;
  my $sth_all_but_newest = $self->dbh->prepare($query_all_but_newest);

  foreach my $ref (@$refs) {
    my @to_delete_ids;
    $sth_all_but_newest->execute($ref->{trans_id}, $ref->{config_id}, $ref->{sub_module}) || $::form->dberror($query_all_but_newest);
    while (my ($row) = $sth_all_but_newest->fetchrow_array()) {
      push(@to_delete_ids, $row);
    }
    ($sth_delete->execute($_) || $::form->dberror($query_delete)) for @to_delete_ids;
  }

  $sth_all_but_newest->finish;
  $sth_delete->finish;

  return 1;
}

1;
