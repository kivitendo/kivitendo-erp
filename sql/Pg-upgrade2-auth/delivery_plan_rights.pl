# @tag: delivery_plan_rights
# @description: Setzt das neue Recht den Lieferplan anzuzeigen
# @depends: release_3_0_0
package SL::DBUpgrade2::delivery_plan_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{delivery_plan_rights} = $group->{rights}->{sales_order_edit};
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
