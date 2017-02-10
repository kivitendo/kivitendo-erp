# @tag: record_links_rights
# @description: Setzt das Recht um den Tab verknüpfte Belege zu sehen, per Default erlaubt (wie vorher auch)
# @depends: release_3_4_0 master_rights_position_gaps
package SL::DBUpgrade2::Auth::record_links_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES ( 4750, 'record_links', 'Linked Records')");

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{record_links} = 1;
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
