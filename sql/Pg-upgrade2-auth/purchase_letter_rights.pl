# @tag: purchase_letter_rights
# @description: Neue Rechte für Lieferantenbriefe
# @depends: release_3_4_0 add_master_rights master_rights_position_gaps
# @locales: Edit purchase letters
# @locales: Show purchase letters report
package SL::DBUpgrade2::Auth::purchase_letter_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES (?, ?, ?)", bind => $_) for
    [ 2550, 'purchase_letter_edit',   'Edit purchase letters'        ],
    [ 2650, 'purchase_letter_report', 'Show purchase letters report' ];

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{purchase_letter_edit} = $group->{rights}->{purchase_order_edit};
    $group->{rights}->{purchase_letter_report} = $group->{rights}->{purchase_order_edit};
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
