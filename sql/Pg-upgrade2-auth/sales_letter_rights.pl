# @tag: sales_letter_rights
# @description: Setzt das neue Recht die Brieffunktion anzuzeigen
# @depends: release_3_2_0 add_master_rights
package SL::DBUpgrade2::Auth::sales_letter_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{sales_letter_edit} = $group->{rights}->{sales_order_edit};
    $group->{rights}->{sales_letter_report} = $group->{rights}->{sales_order_edit};
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
