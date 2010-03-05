# @tag: rundungsfehler_korrigieren_BUG1328-2
# @description: Die entsprechende Cent-Abweichung die durch den Rundungsfehler in Bug 1328 behoben wurde, entsprechende für alte Buchungen korrigieren.
# @depends: release_2_6_0
# @charset: utf-8

use strict;
use Data::Dumper;
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
  my @queries;


  my $query = qq|select distinct id,acamount from (select ap.id,ap.amount as apamount, ac.amount*-1 as acamount from ap left join acc_trans ac on (ac.trans_id =
ap.id) where ac.chart_id IN (select id from chart where link ='AP' OR link like '%:AP' OR link like 'AP:%')) as foo where  apamount + 0.01 = abs(acamount)|;
  my $sth_all_groups = prepare_execute_query($form, $dbh, $query);
  while (my $hash_ref = $sth_all_groups->fetchrow_hashref()) {  # Schleife
      push @queries, "UPDATE ap set amount =" . $hash_ref->{acamount} . " WHERE id = " . $hash_ref->{id};
  }
  $sth_all_groups->finish();


  my $query = qq|select distinct id,acamount from (select ar.id, ar.amount as aramount, ac.amount*-1 as acamount from ar left join acc_trans ac on (ac.trans_id =
ar.id) where ac.chart_id IN (select id from chart where link ='AR' OR link like '%:AR' OR link like 'AR:%')) as foo where  aramount + 0.01 = abs(acamount)|;
  my $sth_all_groups = prepare_execute_query($form, $dbh, $query);
  while (my $hash_ref = $sth_all_groups->fetchrow_hashref()) {  # Schleife
      # Falls wir keine alte buggy Installation haben, ist es super die 
      # Gewissheit zu haben, dass kein acc_trans-Eintrag ohne trans_id vorhanden ist
      push @queries, "UPDATE ar set amount =" . $hash_ref->{acamount} . " WHERE id = " . $hash_ref->{id};
  }
  $sth_all_groups->finish();

  # if in doubt use brute force ;-) jb
  foreach my $query (@queries){
    my $sth   = prepare_query($form, $dbh, $query);
    do_statement($form,$sth,$query);
    $sth->finish();
  }
  $dbh ->commit();
  return 1;
}

return do_update();

