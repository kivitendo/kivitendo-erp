#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#
# XIII form retrieval
#
#======================================================================

package XIII;


sub retrieve_form {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);
  my $query = qq|SELECT f.line
                 FROM xiii_forms f
                 WHERE f.file = '$form->{file}'
		 AND f.dbname = '$myconfig->{dbname}'
		 ORDER BY f.oid|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  my $ref;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{body} }, $ref->{line};
  }
  
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}



sub delete_form {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM xiii_forms
                 WHERE file = '$form->{file}'
		 AND dbname = '$myconfig->{dbname}'|;
  $dbh->do($query) || $form->dberror($query);
  
  # commit and redirect
  $rc = $dbh->commit;
  $dbh->disconnect;
    
  $main::lxdebug->leave_sub();

  return $rc;
}


sub save_form {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM xiii_forms
                 WHERE file = '$form->{file}'
		 AND dbname = '$myconfig->{dbname}'|;
  $dbh->do($query) || $form->dberror($query);
  
 
  $query = qq|INSERT INTO xiii_forms (line, file, dbname)
              VALUES (?, '$form->{file}', '$myconfig->{dbname}')|;
    
  $sth = $dbh->prepare($query);


  foreach $line (split /\r/, $form->{body}) {
    $sth->execute($line) || $form->dberror($query);
    $sth->finish;
  }

  $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}


1;

