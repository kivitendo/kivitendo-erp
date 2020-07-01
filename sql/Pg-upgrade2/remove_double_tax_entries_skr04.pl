# @tag: remove_double_tax_entries_skr04
# @description: doppelte Steuer-Einträge und alte 16% Konten für SKR04 entfernen, wenn unbebucht
# @depends: release_3_5_5
package SL::DBUpgrade2::remove_double_tax_entries_skr04;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  if (!$self->check_coa('Germany-DATEV-SKR04EU')) {
    return 1;
  }

  my $query = <<SQL;
    SELECT id FROM tax WHERE chart_id = (SELECT id FROM chart WHERE accno LIKE ?) AND taxkey = ? AND rate = ? ORDER BY id;
SQL

  my $query2 = <<SQL;
    DELETE FROM taxkeys WHERE tax_id = ?;
SQL

  my $query3 = <<SQL;
    DELETE FROM tax WHERE id = ?;
SQL

  my @taxes_to_test = (
    {accno => '3806', taxkey => 3, rate => 0.19},
    {accno => '1406', taxkey => 9, rate => 0.19},
    {accno => '3805', taxkey => 5, rate => 0.16},
    {accno => '1405', taxkey => 7, rate => 0.16},

  );

  foreach my $tax_to_test (@taxes_to_test) {
    my @entries = selectall_hashref_query($::form, $self->dbh, $query, ($tax_to_test->{accno}, $tax_to_test->{taxkey}, $tax_to_test->{rate}));

    if (scalar @entries > 1) {
      foreach my $tax (@entries) {
        my ($num_acc_trans_entries) = $self->dbh->selectrow_array("SELECT COUNT(*) FROM acc_trans WHERE tax_id = ?", undef, $tax->{id});
        next if $num_acc_trans_entries > 0;

        $self->db_query($query2, bind => [ $tax->{id} ]);
        $self->db_query($query3, bind => [ $tax->{id} ]);

        last; # delete only one tax
      }
    }
  }

  return 1;
}

1;
