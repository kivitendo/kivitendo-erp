# @tag: globalprojectnumber_ap_ar_oe
# @description: Neue Spalte f&uuml;r eine globale Projektnummer in Einkaufs- und Verkaufsbelegen
# @depends: release_2_4_1

use strict;

# import vars from caller
our ($dbup_locale, $dbup_myconfig, $dbh);

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
  my @queries =
    ("ALTER TABLE ap ADD COLUMN globalproject_id integer;",
     "ALTER TABLE ap ADD FOREIGN KEY (globalproject_id) REFERENCES project (id);",
     "ALTER TABLE ar ADD COLUMN globalproject_id integer;",
     "ALTER TABLE ar ADD FOREIGN KEY (globalproject_id) REFERENCES project (id);",
     "ALTER TABLE oe ADD COLUMN globalproject_id integer;",
     "ALTER TABLE oe ADD FOREIGN KEY (globalproject_id) REFERENCES project (id);");

  do_query("ALTER TABLE project ADD PRIMARY KEY (id);", 1);
  map({ do_query($_, 0); } @queries);

  return 1;
}

return do_update();

