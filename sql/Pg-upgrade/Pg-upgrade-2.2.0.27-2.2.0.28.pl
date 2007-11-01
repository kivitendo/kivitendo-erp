#!/usr/bin/perl

die("This script cannot be run from the command line.") unless ($main::form);

sub mydberror {
  my ($dbup_locale, $msg) = @_;
  die($dbup_locale->text("Database update error:") .
      "<br>$msg<br>" . $DBI::errstr);
}

sub myshowerror {
  my ($msg) = @_;

  print($main::form->parse_html_template("dbupgrade/units_error", { "message" => $msg }));
  return 2;
}

sub update_defaults_add_coa {
  if ($dbh->do("ALTER TABLE defaults ADD COLUMN coa text")) {
    $dbh->commit();
  } else {
    $dbh->rollback();
  }
  $dbh->begin_work();
}

sub update_defaults_set_coa {
  my ($coa) = @_;

  $dbh->do("UPDATE defaults SET coa = " . $dbh->quote($coa));

  return 1;
}

sub look_for_accno {
  my ($accno) = @_;

  my ($result) =
    $dbh->selectrow_array("SELECT COUNT(*) FROM chart WHERE accno = " .
                          $dbh->quote($accno));

  return $result;
}

sub update_guess_chart_of_accounts {
  update_defaults_add_coa();

  my $form = $main::form;

  my @valid_coas = map({ s/^sql\///; s/-chart.sql//; $_; } <sql/*-chart.sql>);

  my $query = "SELECT coa FROM defaults";
  my ($coa) = $dbh->selectrow_array($query);

  return 1 if (grep({ $coa eq $_ } @valid_coas));

  return update_defaults_set_coa("Germany-DATEV-SKR04EU")
    if (look_for_accno("6595"));

  return update_defaults_set_coa("Germany-DATEV-SKR03EU")
    if (look_for_accno("2725"));

  return update_defaults_set_coa("Austria")
    if (look_for_accno("2701"));

  return update_defaults_set_coa("France")
    if (look_for_accno("131800"));

  return update_defaults_set_coa("Swiss-German")
    if (look_for_accno("21235"));

  return update_defaults_set_coa($form->{"coa"})
    if (($form->{"action2"} eq "set_coa") &&
        grep({ $form->{"coa"} eq $_ } @valid_coas));

  my @coas = map(+{ "name" => $_ }, @valid_coas);

  print($form->parse_html_template("dbupgrade/coa_guess", { "COAS" => \@coas }));

  return 2;
}

return update_guess_chart_of_accounts();
