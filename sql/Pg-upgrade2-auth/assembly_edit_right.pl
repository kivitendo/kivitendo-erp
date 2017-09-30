# @tag: assembly_edit_right
# @description: Setzt das Recht Erzeugnisbestandteile editieren, auch nachdem es schon erstmalig erzeugt wurde.
# @depends: release_3_5_0 master_rights_position_gaps
# @locales: Always edit assembly items (user can change/delete items even if assemblies are already produced)
package SL::DBUpgrade2::Auth::assembly_edit_right;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES ( 550, 'assembly_edit', 'Always edit assembly items (user can change/delete items even if assemblies are already produced)')");

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{assembly_edit} = 0;
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
