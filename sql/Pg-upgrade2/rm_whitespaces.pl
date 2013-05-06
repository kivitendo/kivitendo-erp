# @tag: rm_whitespaces
# @description: Entfernt mögliche Leerzeichen am Anfang und Ende jeder Währung
# @depends: release_3_0_0
# @charset: utf-8

use utf8;
use strict;

die("This script cannot be run from the command line.") unless ($main::form);

sub mydberror {
  my ($msg) = @_;
  die($dbup_locale->text("Database update error:") . "<br>$msg<br>" . $DBI::errstr);
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
  my $query = qq|UPDATE ar SET curr = RTRIM(LTRIM(curr))|;
  do_query($query);
  $query = qq|UPDATE ap SET curr = RTRIM(LTRIM(curr))|;
  do_query($query);
  $query = qq|UPDATE oe SET curr = RTRIM(LTRIM(curr))|;
  do_query($query);
  $query = qq|UPDATE customer SET curr = RTRIM(LTRIM(curr))|;
  do_query($query);
  $query = qq|UPDATE delivery_orders SET curr = RTRIM(LTRIM(curr))|;
  do_query($query);
  $query = qq|UPDATE exchangerate SET curr = RTRIM(LTRIM(curr))|;
  do_query($query);
  $query = qq|UPDATE vendor SET curr = RTRIM(LTRIM(curr))|;
  do_query($query);

  $query = qq|SELECT curr FROM defaults|;
  my ($curr)     = selectrow_query($self, $dbh, $query);

  $curr  =~ s/ //g;

  $query = qq|UPDATE defaults SET curr = '$curr'|;
  do_query($query);
  return 1;
};

return do_update();
