# @tag: delivery_process_value
# @description: Setzt das neue Recht den Lieferstatus mit Warenwert zu sehen
# @depends: release_3_2_0 add_master_rights
package SL::DBUpgrade2::Auth::delivery_process_value;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{delivery_value_report} = $group->{rights}->{sales_order_edit};
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
