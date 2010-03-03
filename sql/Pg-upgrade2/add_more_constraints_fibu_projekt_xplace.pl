# @tag: add_more_constraints_fibu_projekt_xplace3
# @description: Falls der Datenbestand es unproblematisch hergibt, ein paar 'schärfere' Constraints für die acc_trans gesetzt. Keine acc_trans-Eintrag ohne trans_id oder chart_id. Ferner project_id in acc_trans als Fremdschlüssel für project definiert.
# @depends: release_2_6_0 fix_acc_trans_ap_taxkey_bug
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

  # die project_id in der acc_trans ist auch zwingend fremdschlüssel in project 
  push @queries, "ALTER TABLE acc_trans ADD FOREIGN KEY (project_id) REFERENCES project(id)";

  my $query = qq|select count(*) from acc_trans where chart_id is NULL|;
  my $sth_all_groups = prepare_execute_query($form, $dbh, $query);
  while (my $hash_ref = $sth_all_groups->fetchrow_hashref()) {  # Schleife
    if ($hash_ref->{count} eq 0){
      # Falls wir keine alte buggy Installation haben, ist es super die 
      # Gewissheit zu haben, dass kein acc_trans-Eintrag ohne chart_id vorhanden ist
      push @queries, "ALTER TABLE acc_trans ALTER COLUMN chart_id SET NOT NULL";
    }
  }
  $sth_all_groups->finish();
  my $query = qq|select count(*) from acc_trans where trans_id is NULL|;
  my $sth_all_groups = prepare_execute_query($form, $dbh, $query);
  while (my $hash_ref = $sth_all_groups->fetchrow_hashref()) {  # Schleife
    if ($hash_ref->{count} eq 0){
      # Falls wir keine alte buggy Installation haben, ist es super die 
      # Gewissheit zu haben, dass kein acc_trans-Eintrag ohne trans_id vorhanden ist
      push @queries, "ALTER TABLE acc_trans ALTER COLUMN trans_id SET NOT NULL";
    }
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

