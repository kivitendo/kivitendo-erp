# @tag: requirement_spec_rights
# @description: Neues Gruppenrecht für Pflichtenhefte
# @depends: release_3_0_0
package SL::DBUpgrade2::requirement_spec_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  my $groups = $::auth->read_groups;

  foreach my $group (values %{$groups}) {
    $group->{rights}->{requirement_spec_edit} = $group->{rights}->{sales_quotation_edit} ? 1 : 0;
    $::auth->save_group($group);
  }

  return 1;
}

1;
