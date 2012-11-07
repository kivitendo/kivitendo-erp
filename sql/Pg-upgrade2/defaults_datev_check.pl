# @tag: defaults_datev_check
# @description: Einstellung für DATEV-Überprüfungen (datev_check) vom Config-File in die DB verlagern.
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
  do_query(qq|ALTER TABLE defaults ADD COLUMN datev_check_on_sales_invoice boolean    DEFAULT true|, 1);
  do_query(qq|ALTER TABLE defaults ADD COLUMN datev_check_on_purchase_invoice boolean DEFAULT true|, 1);
  do_query(qq|ALTER TABLE defaults ADD COLUMN datev_check_on_ar_transaction boolean   DEFAULT true|, 1);
  do_query(qq|ALTER TABLE defaults ADD COLUMN datev_check_on_ap_transaction boolean   DEFAULT true|, 1);
  do_query(qq|ALTER TABLE defaults ADD COLUMN datev_check_on_gl_transaction boolean   DEFAULT true|, 1);

  # check current configuration and set default variables accordingly, so that
  # kivitendo's behaviour isn't changed by this update
  # if checks are not set in config set it to true
  foreach my $check (qw(check_on_sales_invoice check_on_purchase_invoice check_on_ar_transaction check_on_ap_transaction check_on_gl_transaction)) {
    my $check_set = 1;
    if (!$::lx_office_conf{datev_check}->{$check}) {
      $check_set = 0;
    }

    my $update_column = "UPDATE defaults SET datev_$check = '$check_set';";
    do_query($update_column);
  }


  return 1;
}

return do_update();

