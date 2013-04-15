# @tag: erzeugnisnummern
# @description: Erzeugnisnummern und Artikelnummern sollen eindeutig sein.
# @depends: release_3_0_0
# @charset: utf-8

use utf8;
use strict;
use SL::Locale;

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
    my $query = qq|SELECT id, partnumber, description, unit, notes, assembly, ean, inventory_accno_id
                   FROM parts pa
                   WHERE (SELECT COUNT(*)
                          FROM parts p
                          WHERE p.partnumber=pa.partnumber)
                          > 1
                   ORDER BY partnumber;|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $main::form->dberror($query);

  $main::form->{PARTS} = [];
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    push @{ $main::form->{PARTS} }, $ref;
  }

  if ( scalar @{ $main::form->{PARTS} } > 0 ) {
    &print_error_message;
    return 0;
  }

  $query = qq|ALTER TABLE parts ADD UNIQUE (partnumber)|;
  do_query($query);

  $query = qq|ALTER TABLE defaults ADD assemblynumber TEXT|;
  do_query($query);
  return 1;
}; # end do_update


sub print_error_message {
  print $main::form->parse_html_template("dbupgrade/erzeugnisnummern");
}

return do_update();
