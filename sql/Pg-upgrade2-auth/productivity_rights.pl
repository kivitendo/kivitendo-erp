# @tag: productivity_rights
# @description: Setzt das Recht die Produktivität einzusehen und das Recht den Link zum Admin-Menü anzuzeigen wieder wie vorher
# @depends: release_3_2_0 add_master_rights
package SL::DBUpgrade2::Auth::productivity_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{productivity}       = 1;
    $group->{rights}->{display_admin_link} = 1;
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
