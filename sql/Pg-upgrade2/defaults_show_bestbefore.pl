# @tag: defaults_show_bestbefore
# @description: Einstellung, ob Mindesthaltbarkeitsdatum angezeigt wird, vom Config-File in die DB verlagern.
# @depends: release_2_7_0
package SL::DBUpgrade2::defaults_show_bestbefore;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN show_bestbefore boolean DEFAULT false|, may_fail => 1);

  # check current configuration and set default variables accordingly, so that
  # kivitendo behaviour isn't changed by this update
  # if show_best_before is not set in config set it to 0
  my $show_bestbefore = 0;
  if ($::lx_office_conf{features}->{show_best_before}) {
    $show_bestbefore = 1;
  }

  my $update_column = "UPDATE defaults SET show_bestbefore = '$show_bestbefore';";
  $self->db_query($update_column);

  return 1;
}

1;
