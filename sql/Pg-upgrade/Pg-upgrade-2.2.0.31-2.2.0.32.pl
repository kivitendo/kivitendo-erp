#!/usr/bin/perl

die("This script cannot be run from the command line.") unless ($main::form);

sub mydberror {
  my ($msg) = @_;
  die($dbup_locale->text("Database update error:") .
      "<br>$msg<br>" . $DBI::errstr);
}

sub myshowerror {
  my ($msg) = @_;

  print($main::form->parse_html_template("dbupgrade/units_error", { "message" => $msg }));
  return 2;
}


sub update_steuersaetze_skr03 {
  my $query;

  $query = "SELECT COUNT(*) FROM chart " .
    "WHERE accno = '1776'";
  my ($count) = $dbh->selectrow_array($query);

  if (!$count) {
    $query =
      qq|INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_ustva, pos_eur)
      VALUES ('1776','Umsatzsteuer 19 %', 'A', 'I', 'AR_tax:IC_taxpart:IC_taxservice:CT_tax', 0, 511,6)|;
    $dbh->do($query) || mydberror($query);
  }
  $query = "SELECT COUNT(*) FROM chart " .
    "WHERE accno = '1576'";
  my ($count) = $dbh->selectrow_array($query);

  if (!$count) {
    $query =
      qq|INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_ustva, pos_eur)
      VALUES ('1576','Abziehbare Vorsteuer 19 %', 'A', 'E', 'AP_tax:IC_taxpart:IC_taxservice:CT_tax', 0, 66,27)|;
    $dbh->do($query) || mydberror($query);
  }

  $query =
    qq|INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id from CHART WHERE accno='1776'), 0.19, '1776', 3, 'Umsatzsteuer 19%')|;
  $dbh->do($query) || mydberror($query);
  $query =
    qq|INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id from CHART WHERE accno='1576'), 0.19, '1576', 9, 'Vorsteuer 19%')|;
  $dbh->do($query) || mydberror($query);

  $query =
    qq|insert into taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate) select chart.id, (SELECT id from tax where taxdescription='Umsatzsteuer 19%'), 3, pos_ustva, '2007-01-01' from chart WHERE taxkey_id=3|;
  $dbh->do($query) || mydberror($query);

  $query =
    qq|insert into taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate) select chart.id, (SELECT id from tax where taxdescription='Vorsteuer 19%'), 9, pos_ustva, '2007-01-01' from chart WHERE taxkey_id=9|;
  $dbh->do($query) || mydberror($query);


  return 1;
}

sub update_steuersaetze_skr04 {
  my $query;

  $query = "SELECT COUNT(*) FROM chart " .
    "WHERE accno = '3806'";
  my ($count) = $dbh->selectrow_array($query);

  if (!$count) {
    $query =
      qq|INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_ustva, pos_eur)
      VALUES ('3806','Umsatzsteuer 19 %', 'A', 'I', 'AR_tax:IC_taxpart:IC_taxservice:CT_tax', 0, 511,6)|;
    $dbh->do($query) || mydberror($query);
  }
  $query = "SELECT COUNT(*) FROM chart " .
    "WHERE accno = '1406'";
  my ($count) = $dbh->selectrow_array($query);

  if (!$count) {
    $query =
      qq|INSERT INTO chart (accno, description, charttype, category, link, taxkey_id, pos_ustva, pos_eur)
      VALUES ('1406','Abziehbare Vorsteuer 19 %', 'A', 'E', 'AP_tax:IC_taxpart:IC_taxservice:CT_tax', 0, 66,27)|;
    $dbh->do($query) || mydberror($query);
  }

  $query =
    qq|INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id from CHART WHERE accno='3806'), 0.19, '3806', 3, 'Umsatzsteuer 19%')|;
  $dbh->do($query) || mydberror($query);
  $query =
    qq|INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription) VALUES ((SELECT id from CHART WHERE accno='1406'), 0.19, '1406', 9, 'Vorsteuer 19%')|;
  $dbh->do($query) || mydberror($query);

  $query =
    qq|insert into taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate) select chart.id, (SELECT id from tax where taxdescription='Umsatzsteuer 19%'), 3, pos_ustva, '2007-01-01' from chart WHERE taxkey_id=3|;
  $dbh->do($query) || mydberror($query);

  $query =
    qq|insert into taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate) select chart.id, (SELECT id from tax where taxdescription='Vorsteuer 19%'), 9, pos_ustva, '2007-01-01' from chart WHERE taxkey_id=9|;
  $dbh->do($query) || mydberror($query);


  return 1;
}


sub update_steuersaetze {
  my $form = $main::form;

  my $query = "SELECT coa FROM defaults";
  my ($coa) = $dbh->selectrow_array($query);

  if ($coa eq "Germany-DATEV-SKR03EU") {
    return update_steuersaetze_skr03();

  } elsif ($coa eq "Germany-DATEV-SKR04EU") {
    return update_steuersaetze_skr04();
  }

  print($form->parse_html_template("dbupgrade/std_buchungsgruppen_unknown_coa", { "coa" => $coa }));

  return 1;
}



return update_steuersaetze();
