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

sub update_contacts_add_columns {
  # The following columns might already be present due to an
  # existing CRM installation:
  mydoquery("ALTER TABLE contacts ADD COLUMN cp_fax text", 1);

  # The following columns should not exist:
  mydoquery("ALTER TABLE contacts ADD COLUMN cp_mobile1 text");
  mydoquery("ALTER TABLE contacts ADD COLUMN cp_mobile2 text");
  mydoquery("ALTER TABLE contacts ADD COLUMN cp_satphone text");
  mydoquery("ALTER TABLE contacts ADD COLUMN cp_satfax text");
  mydoquery("ALTER TABLE contacts ADD COLUMN cp_project text");
  mydoquery("ALTER TABLE contacts ADD COLUMN cp_privatphone text");
  mydoquery("ALTER TABLE contacts ADD COLUMN cp_privatemail text");
  mydoquery("ALTER TABLE contacts ADD COLUMN cp_birthday text");

  return 1;
}

return update_contacts_add_columns();
