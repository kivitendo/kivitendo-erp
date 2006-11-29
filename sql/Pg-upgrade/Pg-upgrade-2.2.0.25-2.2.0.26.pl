#!/usr/bin/perl

die("This script cannot be run from the command line.") unless ($main::form);

use SL::AM;

%dbup_myconfig = ();
map({ $dbup_myconfig{$_} = $main::form->{$_}; }
    qw(dbname dbuser dbpasswd dbhost dbport dbconnect));

sub mydberror {
  my ($dbup_locale, $msg) = @_;
  die($dbup_locale->text("Database update error:") .
      "<br>$msg<br>" . $DBI::errstr);
}

sub myshowerror {
  my ($msg) = @_;

  print($main::form->parse_html_template("dbupgrade/units_error",
                                         { "message" => $msg }));
  return 2;
}

sub update_units_add_unit {
  my ($dbup_locale, $dbh) = @_;

  my $form = $main::form;

  return 0 unless ($form->{"new_name"});

  return myshowerror($dbup_locale->text("The name is missing."))
    if ($form->{"new_name"} eq "");
  my $units = AM->retrieve_units(\%dbup_myconfig, $form);
  return myshowerror($dbup_locale->text("A unit with this name does already exist."))
    if ($units->{$form->{"new_name"}});
  $units = AM->retrieve_units(\%dbup_myconfig, $form, $form->{"unit_type"});

  my ($base_unit, $factor);
  if ($form->{"new_base_unit"}) {
    return myshowerror($dbup_locale->text("The base unit does not exist."))
      unless (defined($units->{$form->{"new_base_unit"}}));

    return myshowerror($dbup_locale->text("The factor is missing."))
      if ($form->{"new_factor"} eq "");
    $factor = $form->parse_amount(\%dbup_myconfig, $form->{"new_factor"});
    return myshowerror($dbup_locale->text("The factor is missing."))
      unless ($factor);
    $base_unit = $form->{"new_base_unit"};
  }

  my $query = "INSERT INTO units " .
    "(name, base_unit, factor, type) " .
    "VALUES (?, ?, ?, ?)";
  $dbh->do($query, undef, $form->{"new_name"}, $base_unit, $factor,
           $form->{"unit_type"}) ||
    mydberror($dbup_locale, $query .
              " ($form->{new_name}, $base_unit, $factor, $form->{unit_type})");
  $dbh->commit();
  $dbh->begin_work();

  $form->{"saved_message"} = $dbup_locale->text("The unit has been saved.");

  return 0;
}

sub update_units_assign_units {
  my ($dbup_locale, $dbh) = @_;

  my ($query, $sth, @values);

  my $form = $main::form;

  foreach my $table (qw(parts invoice orderitems rmaitems)) {
    $query = "UPDATE $table SET unit = ? WHERE lower(unit) = ?";
    $sth = $dbh->prepare($query);

    for (my $i = 1; $i <= $form->{"rowcount"}; $i++) {
      next unless ($form->{"new_unit_$i"} && $form->{"old_unit_$i"});
      @values = ($form->{"new_unit_$i"}, lc($form->{"old_unit_$i"}));
      $sth->execute(@values) ||
        mydberror($dbup_locale, $query . " (" . join(", ", @values) . ")");
    }
  }

  $sth->finish();
  $dbh->commit();
  $dbh->begin_work();
}

sub update_units_assign_known {
  my ($dbup_locale, $dbh) = @_;

  my $form = $main::form;

  my %unit_name_mapping = (
    "st" => "Stck",
    "st." => "Stck",
    "pc" => "Stck",
    "pcs" => "Stck",
    "ea" => "Stck",
    );

  my $i = 1;
  foreach my $k (keys(%unit_name_mapping)) {
    $form->{"old_unit_$i"} = $k;
    $form->{"new_unit_$i"} = $unit_name_mapping{$k};
    $i++;
  }
  $form->{"rowcount"} = scalar(keys(%unit_name_mapping));

  update_units_assign_units($dbup_locale, $dbh);
}

sub update_units_steps_1_2 {
  my ($dbup_locale, $dbh) = @_;

  my (%unknown_dimension_units, %unknown_service_units);

  my $form = $main::form;

  foreach my $table (qw(parts invoice orderitems rmaitems)) {
    my ($query, $sth, $ref);

    if ($table eq "parts") {
      $query = "SELECT unit, inventory_accno_id FROM parts " .
        "WHERE NOT ((unit = '') OR unit ISNULL OR " .
        "           unit IN (SELECT name FROM units))";

    } else {
      $query = "SELECT t.unit, p.inventory_accno_id " .
        "FROM $table t " .
        "LEFT JOIN parts p ON p.id = t.parts_id " .
        "WHERE NOT ((t.unit = '') OR t.unit ISNULL OR " .
        "           t.unit IN (SELECT name FROM units))";
    }
    $sth = $dbh->prepare($query);
    $sth->execute() || mydberror($dbup_locale, $query);

    while ($ref = $sth->fetchrow_hashref()) {
      if ($ref->{"inventory_accno_id"}) {
        $unknown_dimension_units{$ref->{"unit"}} = 1;

      } else {
        $unknown_service_units{$ref->{"unit"}} = 1;
      }
    }

    $sth->finish();
  }

  if (scalar(keys(%unknown_dimension_units)) != 0) {
    my $units = AM->retrieve_units(\%dbup_myconfig, $form, "dimension");
    my $ddbox = AM->unit_select_data($units, undef, 1);

    my @unknown_parts;
    map({ push(@unknown_parts, { "name" => $_, "NEW_UNITS" => $ddbox }); }
        sort({ lc($a) cmp lc($b) } keys(%unknown_dimension_units)));

    print($form->parse_html_template("dbupgrade/units_parts",
                                     { "NEW_BASE_UNIT_DDBOX" => $ddbox,
                                       "UNKNOWN_PART_UNITS" => \@unknown_parts,
                                     }));

    return 2;

  } else {
    print($form->parse_html_template("dbupgrade/units_parts_done"));
  }

  if (scalar(keys(%unknown_service_units)) != 0) {
    my $units = AM->retrieve_units(\%dbup_myconfig, $form, "service");
    my $ddbox = AM->unit_select_data($units, undef, 1);

    my @unknown_services;
    map({ push(@unknown_services, { "name" => $_, "NEW_UNITS" => $ddbox }); }
        sort({ lc($a) cmp lc($b) } keys(%unknown_service_units)));

    print($form->parse_html_template("dbupgrade/units_services",
                                     { "NEW_BASE_UNIT_DDBOX" => $ddbox,
                                       "UNKNOWN_PART_UNITS" => \@unknown_services,
                                     }));

    return 2;

  } else {
    print($form->parse_html_template("dbupgrade/units_services_done"));
  }

  return 0;
}

sub update_units_step_3 {
  my ($dbup_locale, $dbh) = @_;

  my $form = $main::form;

  my $query = "SELECT ";
  foreach my $table (qw(parts invoice orderitems rmaitems)) {
    $query .= "(SELECT COUNT(*) FROM $table " .
      "WHERE (unit ISNULL) OR (unit = '')) +";
  }
  substr($query, -1, 1) = "AS has_unassigned";
  my ($has_unassigned) = $dbh->selectrow_array($query);

  if ($has_unassigned) {
    my $dimension_units = AM->retrieve_units(\%dbup_myconfig, $form,
                                             "dimension");
    my $dimension_ddbox = AM->unit_select_data($dimension_units);

    my $service_units = AM->retrieve_units(\%dbup_myconfig, $form, "service");
    my $service_ddbox = AM->unit_select_data($service_units);

    print($form->parse_html_template("dbupgrade/units_set_default",
                                     { "DIMENSION_DDBOX" => $dimension_ddbox,
                                       "SERVICE_DDBOX" => $service_ddbox }));
    return 2;

  } else {
    print($form->parse_html_template("dbupgrade/units_set_default_done"));
    return 1;
  }
}

sub update_units_set_default {
  my ($dbup_locale, $dbh) = @_;

  my $form = $main::form;

  foreach my $table (qw(parts invoice orderitems rmaitems)) {
    my $base_query = "UPDATE $table SET unit = " .
      $dbh->quote($form->{"default_service_unit"}) . " " .
      "WHERE ((unit ISNULL) OR (unit = '')) AND ";
    my $query;

    if ($table eq "parts") {
      $query = "UPDATE $table SET unit = " .
        $dbh->quote($form->{"default_dimension_unit"}) . " " .
        "WHERE ((unit ISNULL) OR (unit = '')) AND (inventory_accno_id > 0)";
    } else {
      $query = "UPDATE $table SET unit = " .
        $dbh->quote($form->{"default_dimension_unit"}) . " " .
        "WHERE ((unit ISNULL) OR (unit = '')) AND " .
        "parts_id IN (SELECT id FROM parts WHERE (inventory_accno_id > 0))";
    }

    $dbh->do($query) || mydberror($dbup_locale, $query);

    if ($table eq "parts") {
      $query = "UPDATE $table SET unit = " .
        $dbh->quote($form->{"default_service_unit"}) . " " .
        "WHERE ((unit ISNULL) OR (unit = '')) AND " .
        "(inventory_accno_id ISNULL) OR (inventory_accno_id = 0)";
    } else {
      $query = "UPDATE $table SET unit = " .
        $dbh->quote($form->{"default_service_unit"}) . " " .
        "WHERE ((unit ISNULL) OR (unit = '')) AND " .
        "parts_id IN (SELECT id FROM parts " .
        "WHERE (inventory_accno_id ISNULL) OR (inventory_accno_id = 0))";
    }

    $dbh->do($query) || mydberror($dbup_locale, $query);
  }
}

sub update_units {
  my (@dbh) = @_;

  my $form = $main::form;

  my $res;

  my $dbup_locale = Locale->new($main::language, "dbupgrade");

  print($form->parse_html_template("dbupgrade/units_header"));

  if ($form->{"action2"} eq "add_unit") {
    $res = update_units_add_unit($dbup_locale, $dbh);
    return $res if ($res);

  } elsif ($form->{"action2"} eq "assign_units") {
    update_units_assign_units($dbup_locale, $dbh);

  } elsif ($form->{"action2"} eq "set_default") {
    update_units_set_default($dbup_locale, $dbh);

  }

  update_units_assign_known($dbup_locale, $dbh);

  $res = update_units_steps_1_2($dbup_locale, $dbh);
  return $res if ($res);

  return update_units_step_3($dbup_locale, $dbh);
}

update_units($dbh);
