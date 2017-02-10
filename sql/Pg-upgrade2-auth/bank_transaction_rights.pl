# @tag: bank_transaction_rights
# @description: Setzt das neue Recht die Bankerweiterung zu nutzen (für Gruppen die auch Recht Kontenabgleich haben)
# @depends: release_3_2_0
package SL::DBUpgrade2::Auth::bank_transaction_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{bank_transaction} = $group->{rights}->{cash};
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
