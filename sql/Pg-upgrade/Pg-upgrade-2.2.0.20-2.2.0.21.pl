#!/usr/bin/perl

die("This script cannot be run from the command line.") unless ($main::form);

sub mydberror {
  my ($msg) = @_;
  die($dbup_locale->text("Database update error:") .
      "<br>$msg<br>" . $DBI::errstr);
}

sub mydoquery {
  my ($query, $allow_fail) = @_;

  if (!$dbh->do($query)) {
    mydberror($query) unless ($allow_fail);
    $dbh->rollback();
    $dbh->begin_work();
  }
}

sub update_contacts_handle_department {
  $dbh->selectrow_array("SELECT cp_abteilung FROM contacts LIMIT 1");
  if ($dbh->err) {
    $dbh->rollback();
    $dbh->begin_work();
    mydoquery("ALTER TABLE contacts ADD COLUMN cp_abteilung text");
    mydoquery("UPDATE contacts SET cp_abteilung = cp_department");
  }

  mydoquery("ALTER TABLE contacts DROP COLUMN cp_department", 1);

  return 1;
}

return update_contacts_handle_department();
