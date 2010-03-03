# @tag: auth_enable_sales_all_edit
# @description: Neues gruppenbezogenes Recht für den Bereich Verkauf hinzugefügt (sales_all_edit := Nur wenn angehakt, können Verkaufsdokumente von anderen Bearbeitern eingesehen werden) Das Skript hakt standardmässig dieses Recht an, sodass es keinen Unterschied zu vorhergehenden Version gibt.
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

#  do_query("ALTER TABLE project ADD PRIMARY KEY (id);", 1);
#  map({ do_query($_, 0); } @queries);
#  print "hieryy";
#  print (Dumper($main::form));
  my $dbh = $main::auth->dbconnect();
  my $query = qq|SELECT distinct group_id from auth.user_group|;
  my $sth_all_groups = prepare_execute_query($form, $dbh, $query);
  while (my $hash_ref = $sth_all_groups->fetchrow_hashref()) {  # Schleife
    push @queries, "INSERT INTO auth.group_rights (group_id, \"right\", granted) VALUES (" . $hash_ref->{group_id} . ", 'sales_all_edit', 't')";
}
# if in doubt use brute force ;-) jb
  foreach my $query (@queries){
#    print "hier:" . $query;
    my $dbh = $main::auth->dbconnect();
    my $sth   = prepare_query($form, $dbh, $query);
    do_statement($form,$sth,$query);
    $sth->finish();
    $dbh ->commit();
}
  return 1;
}

return do_update();

