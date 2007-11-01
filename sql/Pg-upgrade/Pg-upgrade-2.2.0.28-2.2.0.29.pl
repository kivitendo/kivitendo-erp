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

sub fix_skr03 {
  my $query;

  $query =
    "UPDATE chart " .
    "SET link = 'AP_amount:IC_cogs', pos_ustva = 91 " .
    "WHERE accno = '3559'";
  $dbh->do($query) || mydberror($query);

  $dbh->commit();
  $dbh->begin_work();
}

sub fix_skr04 {
  my $query;

  $query =
    "UPDATE chart " .
    "SET link = 'AP_amount:IC_cogs', pos_ustva = 91 " .
    "WHERE accno = '5559'";
  $dbh->do($query) || mydberror($query);

  $dbh->commit();
  $dbh->begin_work();
}

sub create_standard_buchungsgruppen_skr03 {
  my $query;

  $query = "SELECT COUNT(*) FROM buchungsgruppen " .
    "WHERE description = 'Standard 16%'";
  my ($count) = $dbh->selectrow_array($query);

  if (!$count) {
    $query =
      "INSERT INTO buchungsgruppen " .
      "(description, inventory_accno_id, " .
      " income_accno_id_0, expense_accno_id_0, " .
      " income_accno_id_1, expense_accno_id_1, " .
      " income_accno_id_2, expense_accno_id_2, " .
      " income_accno_id_3, expense_accno_id_3) " .
      "VALUES " .
      "('Standard 16%', " .
      # 3980: Bestand Waren
      " (SELECT id FROM chart WHERE accno = '3980'), " .
      # 8400: Erlöse 16% USt.
      # 3400: Wareneingang 16% Vorsteuer
      " (SELECT id FROM chart WHERE accno = '8400'), " .
      " (SELECT id FROM chart WHERE accno = '3400'), " .
      # 8320: Erlöse aus im and.EG-Land steuerpfl.Lieferungen
      # 3550: Steuerfreier innergem.Erwerb
      " (SELECT id FROM chart WHERE accno = '8320'), " .
      " (SELECT id FROM chart WHERE accno = '3550'), " .
      # 8315: Erlös Inland stpfl.EG-Lieferung 16%
      # 3425: Innergem.Erwerb 16% VorSt u. Ust
      " (SELECT id FROM chart WHERE accno = '8315'), " .
      " (SELECT id FROM chart WHERE accno = '3425'), " .
      # 8120: Steuerfreie Umsätze §4Nr.1a UstG
      # 3559: Steuerfreie Einfuhren
      " (SELECT id FROM chart WHERE accno = '8120'), " .
      " (SELECT id FROM chart WHERE accno = '3559'))";
    $dbh->do($query) || mydberror($query);
  }

  $query = "SELECT COUNT(*) FROM buchungsgruppen " .
    "WHERE description = 'Standard 7%'";
  my ($count) = $dbh->selectrow_array($query);

  if (!$count) {
    $query =
      "INSERT INTO buchungsgruppen " .
      "(description, inventory_accno_id, " .
      " income_accno_id_0, expense_accno_id_0, " .
      " income_accno_id_1, expense_accno_id_1, " .
      " income_accno_id_2, expense_accno_id_2, " .
      " income_accno_id_3, expense_accno_id_3) " .
      "VALUES " .
      "('Standard 7%', " .
      # 3980: Bestand Waren
      " (SELECT id FROM chart WHERE accno = '3980'), " .
      # 8300: Erlöse 7% USt.
      # 3300: Wareneingang 7% Vorsteuer
      " (SELECT id FROM chart WHERE accno = '8300'), " .
      " (SELECT id FROM chart WHERE accno = '3300'), " .
      # 8125: Steuerfrei innergem. Lieferungen §41bUStG
      # 3550: Steuerfreier innergem.Erwerb
      " (SELECT id FROM chart WHERE accno = '8125'), " .
      " (SELECT id FROM chart WHERE accno = '3550'), " .
      # 8310: Erlöse Inland stpfl. EG-Lieferung7%
      # 3420: Innergemein.Erwerb 7% VorSt u. Ust
      " (SELECT id FROM chart WHERE accno = '8310'), " .
      " (SELECT id FROM chart WHERE accno = '3420'), " .
      # 8120: Steuerfreie Umsätze §4Nr.1a UstG
      # 3559: Steuerfreie Einfuhren
      " (SELECT id FROM chart WHERE accno = '8120'), " .
      " (SELECT id FROM chart WHERE accno = '3559'))";
    $dbh->do($query) || mydberror($query);
  }

  return 1;
}

sub create_standard_buchungsgruppen_skr04 {
  my $query;

  $query = "SELECT COUNT(*) FROM buchungsgruppen " .
    "WHERE description = 'Standard 16%'";
  my ($count) = $dbh->selectrow_array($query);

  if (!$count) {
    $query =
      "INSERT INTO buchungsgruppen " .
      "(description, inventory_accno_id, " .
      " income_accno_id_0, expense_accno_id_0, " .
      " income_accno_id_1, expense_accno_id_1, " .
      " income_accno_id_2, expense_accno_id_2, " .
      " income_accno_id_3, expense_accno_id_3) " .
      "VALUES " .
      "('Standard 16%', " .
      # 1140: Bestand Waren
      " (SELECT id FROM chart WHERE accno = '1140'), " .
      # 4400: Erlöse 16% USt.
      # 5400: Wareneingang 16% Vorsteuer
      " (SELECT id FROM chart WHERE accno = '4400'), " .
      " (SELECT id FROM chart WHERE accno = '5400'), " .
      # 4125: Steuerfrei innergem. Lieferungen §41bUStG
      # 5550: Steuerfreier innergem.Erwerb
      " (SELECT id FROM chart WHERE accno = '4125'), " .
      " (SELECT id FROM chart WHERE accno = '5550'), " .
      # 4315: Erlös Inland stpfl.EG-Lieferung 16%
      # 5425: Innergem.Erwerb 16% VorSt u. Ust
      " (SELECT id FROM chart WHERE accno = '4315'), " .
      " (SELECT id FROM chart WHERE accno = '5425'), " .
      # 4150: Sonstige steuerfreie Umsätze §42-7UStG
      # 5559: Steuerfreie Einfuhren
      " (SELECT id FROM chart WHERE accno = '4150'), " .
      " (SELECT id FROM chart WHERE accno = '5559'))";
    $dbh->do($query) || mydberror($query);
  }

  $query = "SELECT COUNT(*) FROM buchungsgruppen " .
    "WHERE description = 'Standard 7%'";
  my ($count) = $dbh->selectrow_array($query);

  if (!$count) {
    $query =
      "INSERT INTO buchungsgruppen " .
      "(description, inventory_accno_id, " .
      " income_accno_id_0, expense_accno_id_0, " .
      " income_accno_id_1, expense_accno_id_1, " .
      " income_accno_id_2, expense_accno_id_2, " .
      " income_accno_id_3, expense_accno_id_3) " .
      "VALUES " .
      "('Standard 7%', " .
      # 1140: Bestand Waren
      " (SELECT id FROM chart WHERE accno = '1140'), " .
      # 4300: Erlöse 7%USt
      # 5300: Wareneingang 7% Vorsteuer
      " (SELECT id FROM chart WHERE accno = '4300'), " .
      " (SELECT id FROM chart WHERE accno = '5300'), " .
      # 4125: Steuerfrei innergem. Lieferungen §41bUStG
      # 5550: Steuerfreier innergem.Erwerb
      " (SELECT id FROM chart WHERE accno = '4125'), " .
      " (SELECT id FROM chart WHERE accno = '5550'), " .
      # 4310: Erlöse Inland stpfl. EG-Lieferung7%
      # 5420: Innergemein.Erwerb 7% VorSt u. Ust
      " (SELECT id FROM chart WHERE accno = '4310'), " .
      " (SELECT id FROM chart WHERE accno = '5420'), " .
      # 4150: Sonstige steuerfreie Umsätze §42-7UStG
      # 5559; Steuerfreie Einfuhren
      " (SELECT id FROM chart WHERE accno = '4150'), " .
      " (SELECT id FROM chart WHERE accno = '5559'))";
    $dbh->do($query) || mydberror($query);
  }

  return 1;
}

sub create_standard_buchungsgruppen {
  my $form = $main::form;

  my $query = "SELECT coa FROM defaults";
  my ($coa) = $dbh->selectrow_array($query);

  if ($coa eq "Germany-DATEV-SKR03EU") {
    fix_skr03();
    return create_standard_buchungsgruppen_skr03();

  } elsif ($coa eq "Germany-DATEV-SKR04EU") {
    fix_skr04();
    return create_standard_buchungsgruppen_skr04();
  }

  print($form->parse_html_template("dbupgrade/std_buchungsgruppen_unknown_coa", { "coa" => $coa }));

  return 1;
}

return create_standard_buchungsgruppen();
