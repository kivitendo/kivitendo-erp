# @tag: defaults_posting_config
# @description: Einstellung, ob und wann Zahlungen änderbar sind, vom Config-File in die DB verlagern.
# @depends: release_2_7_0
package SL::DBUpgrade2::defaults_posting_config;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN payments_changeable integer NOT NULL DEFAULT 0|, may_fail => 1);

  # check current configuration and set default variables accordingly, so that
  # kivitendo behaviour isn't changed by this update
  # if payments_changeable is not set in config set it to 0
  my $payments_changeable = 0;
  if (defined $::lx_office_conf{features}{payments_changeable}) {
    if ($::lx_office_conf{features}->{payments_changeable} == 1 ) {
      $payments_changeable = 1;
    } elsif ($::lx_office_conf{features}->{payments_changeable} == 2 ) {
      $payments_changeable = 2;
    }
  }

  my $update_column = "UPDATE defaults SET payments_changeable = '$payments_changeable';";
  $self->db_query($update_column);

  return 1;
}

1;
