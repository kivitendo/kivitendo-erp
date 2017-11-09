# @tag: custom_data_export_rights
# @description: Rechte für benutzerdefinierten Datenexport
# @depends: release_3_5_0
package SL::DBUpgrade2::Auth::custom_data_export_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;
  my $right  = 'custom_data_export_designer';

  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES (4275, '${right}', 'Custom data export')");

  my $groups = $::auth->read_groups;

  foreach my $group (grep { $_->{rights}->{admin} } values %{$groups}) {
    $group->{rights}->{$right} = 1;
    $::auth->save_group($group);
  }

  return 1;
}

1;
