# @tag: defaults_posting_config
# @description: Einstellung, ob und wann Zahlungen änderbar sind, vom Config-File in die DB verlagern.
# @depends: release_2_7_0
# @charset: utf-8

use utf8;
use strict;

die("This script cannot be run from the command line.") unless ($main::form);

sub mydberror {
  my ($msg) = @_;
  die($dbup_locale->text("Database update error:") .
      "<br>$msg<br>" . $DBI::errstr);
}

sub do_query {
  my ($query, $may_fail) = @_;

  if (!$dbh->do($query)) {
    mydberror($query) unless ($may_fail);
    $dbh->rollback();
    $dbh->begin_work();
  }
}

sub do_update {

  # this query will fail if column already exist (new database)
  do_query(qq|ALTER TABLE defaults ADD COLUMN payments_changeable integer NOT NULL DEFAULT 0|, 1);

  # check current configuration and set default variables accordingly, so that
  # Lx-Office behaviour isn't changed by this update
  # if payments_changeable is not set in config set it to 0
  my $payments_changeable = 0;
  if ($::lx_office_conf{features}->{payments_changeable} == 1 ) {
    $payments_changeable = 1;
  } elsif ($::lx_office_conf{features}->{payments_changeable} == 2 ) {
    $payments_changeable = 2;
  }

  my $update_column = "UPDATE defaults SET payments_changeable = '$payments_changeable';";
  do_query($update_column);

  return 1;
}

return do_update();

