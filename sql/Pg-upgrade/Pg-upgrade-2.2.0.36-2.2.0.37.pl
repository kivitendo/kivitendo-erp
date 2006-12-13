#!/usr/bin/perl

# Datenbankupgrade: Potenziell existierenden Primärschlüssel von orderitems

die("This script cannot be run from the command line.") unless ($main::form);

sub do_update {
  my $query = "ALTER TABLE orderitems DROP CONSTRAINT orderitems_pkey";
  if (!$dbh->do($query)) {
    $dbh->rollback();
    $dbh->begin_work();
  }

  return 1;
}

return do_update();
