# @tag: defaults_show_bestbefore
# @description: Einstellung, ob Mindesthaltbarkeitsdatum angezeigt wird, vom Config-File in die DB verlagern.
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
  do_query(qq|ALTER TABLE defaults ADD COLUMN show_bestbefore boolean DEFAULT false|, 1);

  # check current configuration and set default variables accordingly, so that
  # Lx-Office behaviour isn't changed by this update
  # if show_best_before is not set in config set it to 0
  my $show_bestbefore = 0;
  if ($::lx_office_conf{features}->{show_best_before}) {
    $show_bestbefore = 1;
  }

  my $update_column = "UPDATE defaults SET show_bestbefore = '$show_bestbefore';";
  do_query($update_column);

  return 1;
}

return do_update();

