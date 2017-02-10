# @tag: rights_for_showing_ar_and_ap_transactions
# @description: Setzt das Recht zur Anzeige von Debitoren- und Kreditorenbuchungen im Rechnungsbericht
# @depends: release_3_2_0 add_master_rights
package SL::DBUpgrade2::Auth::rights_for_showing_ar_and_ap_transactions;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{show_ar_transactions} = 1;
    $group->{rights}->{show_ap_transactions} = 1;
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
