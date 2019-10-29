# @tag: all_drafts_edit
# @description: Zugriffsrecht auf alle Entwürfe
# @depends: release_3_4_0 add_master_rights master_rights_position_gaps
# @locales: Edit all drafts
# @ignore: 0
package SL::DBUpgrade2::Auth::all_drafts_edit;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES (?, ?, ?)", bind => $_) for
    [ 5000, 'all_drafts_edit',   'Edit all drafts'        ];

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{all_drafts_edit} = $group->{rights}->{email_employee_readall};
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
