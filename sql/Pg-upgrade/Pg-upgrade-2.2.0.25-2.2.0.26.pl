#!/usr/bin/perl

# Datenbankupgrade: Einfuehrung von Einheiten

die("This script cannot be run from the command line.") unless ($main::form);

sub mydberror {
  my ($msg) = @_;
  die($dbup_locale->text("Database update error:") .
      "<br>$msg<br>" . $DBI::errstr);
}

sub myshowerror {
  my ($msg) = @_;

  print $main::form->parse_html_template("dbupgrade/units_error", { "message" => $msg });
  return 2;
}

sub get_base_unit {
  my ($units, $unit_name, $factor) = @_;

  $factor = 1 unless ($factor);

  my $unit = $units->{$unit_name};

  if (!defined($unit) || !$unit->{"base_unit"} ||
      ($unit_name eq $unit->{"base_unit"})) {
    return ($unit_name, $factor);
  }

  return get_base_unit($units, $unit->{"base_unit"}, $factor * $unit->{"factor"});
}

sub retrieve_units {
  my ($myconfig, $form, $type, $prefix) = @_;

  my $query = "SELECT *, base_unit AS original_base_unit FROM units";
  my @values;
  if ($type) {
    $query .= " WHERE (type = ?)";
    @values = ($type);
  }

  my $sth = $dbh->prepare($query);
  $sth->execute(@values) || $form->dberror($query . " (" . join(", ", @values) . ")");

  my $units = {};
  while (my $ref = $sth->fetchrow_hashref()) {
    $units->{$ref->{"name"}} = $ref;
  }
  $sth->finish();

  my $query_lang = "SELECT id, template_code FROM language ORDER BY description";
  $sth = $dbh->prepare($query_lang);
  $sth->execute() || $form->dberror($query_lang);
  my @languages;
  while ($ref = $sth->fetchrow_hashref()) {
    push(@languages, $ref);
  }
  $sth->finish();

  foreach my $unit (values(%{$units})) {
    ($unit->{"${prefix}base_unit"}, $unit->{"${prefix}factor"}) = get_base_unit($units, $unit->{"name"});
  }

  return $units;
}

sub unit_select_data {
  my ($units, $selected, $empty_entry) = @_;

  my $select = [];

  if ($empty_entry) {
    push(@{$select}, { "name" => "", "base_unit" => "", "factor" => "", "selected" => "" });
  }

  foreach my $unit (sort({ lc($a) cmp lc($b) } keys(%{$units}))) {
    push(@{$select}, { "name" => $unit,
                       "base_unit" => $units->{$unit}->{"base_unit"},
                       "factor" => $units->{$unit}->{"factor"},
                       "selected" => ($unit eq $selected) ? "selected" : "" });
  }

  return $select;
}

sub update_units_add_unit {
  my $form = $main::form;

  return 0 unless ($form->{"new_name"});

  return myshowerror($dbup_locale->text("The name is missing."))
    if ($form->{"new_name"} eq "");
  my $units = retrieve_units(\%dbup_myconfig, $form);
  return myshowerror($dbup_locale->text("A unit with this name does already exist."))
    if ($units->{$form->{"new_name"}});
  $units = retrieve_units(\%dbup_myconfig, $form, $form->{"unit_type"});

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
    mydberror($query .
              " ($form->{new_name}, $base_unit, $factor, $form->{unit_type})");
  $dbh->commit();
  $dbh->begin_work();

  $form->{"saved_message"} = $dbup_locale->text("The unit has been saved.");

  return 0;
}

sub update_units_assign_units {
  my ($query, $sth, @values);

  my $form = $main::form;

  foreach my $table (qw(parts invoice orderitems rmaitems)) {
    $query = "UPDATE $table SET unit = ? WHERE lower(unit) = ?";
    $sth = $dbh->prepare($query);

    for (my $i = 1; $i <= $form->{"rowcount"}; $i++) {
      next unless ($form->{"new_unit_$i"} && $form->{"old_unit_$i"});
      @values = ($form->{"new_unit_$i"}, lc($form->{"old_unit_$i"}));
      $sth->execute(@values) ||
        mydberror($query . " (" . join(", ", @values) . ")");
    }
  }

  $sth->finish();
  $dbh->commit();
  $dbh->begin_work();
}

sub update_units_assign_known {
  my $form = $main::form;

  my %unit_name_mapping = (
    "st" => "Stck",
    "st." => "Stck",
    "stk" => "Stck",
    "pc" => "Stck",
    "pcs" => "Stck",
    "ea" => "Stck",

    "h" => "Std",
    "stunde" => "Std",
    "tage" => "Tag",
    );

  my $i = 1;
  foreach my $k (keys(%unit_name_mapping)) {
    $form->{"old_unit_$i"} = $k;
    $form->{"new_unit_$i"} = $unit_name_mapping{$k};
    $i++;
  }
  $form->{"rowcount"} = scalar(keys(%unit_name_mapping));

  update_units_assign_units();
}

sub update_units_steps_1_2 {
  my (%unknown_dimension_units, %unknown_service_units);

  my $form = $main::form;

  foreach my $table (qw(parts invoice orderitems rmaitems)) {
    my ($query, $sth, $ref);

    if ($table eq "parts") {
      $query = "SELECT unit, inventory_accno_id, assembly FROM parts " .
        "WHERE NOT ((unit = '') OR unit ISNULL OR " .
        "           unit IN (SELECT name FROM units))";

    } else {
      $query = "SELECT t.unit, p.inventory_accno_id, p.assembly " .
        "FROM $table t " .
        "LEFT JOIN parts p ON p.id = t.parts_id " .
        "WHERE NOT ((t.unit = '') OR t.unit ISNULL OR " .
        "           t.unit IN (SELECT name FROM units))";
    }
    $sth = $dbh->prepare($query);
    $sth->execute() || mydberror($query);

    while ($ref = $sth->fetchrow_hashref()) {
      if ($ref->{"inventory_accno_id"} || $ref->{"assembly"}) {
        $unknown_dimension_units{$ref->{"unit"}} = 1;

      } else {
        $unknown_service_units{$ref->{"unit"}} = 1;
      }
    }

    $sth->finish();
  }

  if (scalar(keys(%unknown_dimension_units)) != 0) {
    my $units = retrieve_units(\%dbup_myconfig, $form, "dimension");
    my $ddbox = unit_select_data($units, undef, 1);

    my @unknown_parts;
    map({ push(@unknown_parts, { "name" => $_, "NEW_UNITS" => $ddbox }); }
        sort({ lc($a) cmp lc($b) } keys(%unknown_dimension_units)));

    print $form->parse_html_template("dbupgrade/units_parts",
                                     { "NEW_BASE_UNIT_DDBOX" => $ddbox,
                                       "UNKNOWN_PART_UNITS"  => \@unknown_parts,
                                     });

    return 2;

  } else {
    print $form->parse_html_template("dbupgrade/units_parts_done");
  }

  if (scalar(keys(%unknown_service_units)) != 0) {
    my $units = retrieve_units(\%dbup_myconfig, $form, "service");
    my $ddbox = unit_select_data($units, undef, 1);

    my @unknown_services;
    map({ push(@unknown_services, { "name" => $_, "NEW_UNITS" => $ddbox }); }
        sort({ lc($a) cmp lc($b) } keys(%unknown_service_units)));

    print $form->parse_html_template("dbupgrade/units_services",
                                     { "NEW_BASE_UNIT_DDBOX" => $ddbox,
                                       "UNKNOWN_PART_UNITS"  => \@unknown_services,
                                     }));

    return 2;

  } else {
    print $form->parse_html_template("dbupgrade/units_services_done");
  }

  return 0;
}

sub update_units_step_3 {
  my $form = $main::form;

  my $query = "SELECT ";
  foreach my $table (qw(parts invoice orderitems rmaitems)) {
    $query .= "(SELECT COUNT(*) FROM $table " .
      "WHERE (unit ISNULL) OR (unit = '')) +";
  }
  substr($query, -1, 1) = "AS has_unassigned";
  my ($has_unassigned) = $dbh->selectrow_array($query);

  if ($has_unassigned) {
    my $dimension_units = retrieve_units(\%dbup_myconfig, $form,
                                             "dimension");
    my $dimension_ddbox = unit_select_data($dimension_units);

    my $service_units = retrieve_units(\%dbup_myconfig, $form, "service");
    my $service_ddbox = unit_select_data($service_units);

    print $form->parse_html_template("dbupgrade/units_set_default",
                                     { "DIMENSION_DDBOX" => $dimension_ddbox,
                                       "SERVICE_DDBOX"   => $service_ddbox });
    return 2;

  } else {
    print $form->parse_html_template("dbupgrade/units_set_default_done");
    return 1;
  }
}

sub update_units_set_default {
  my $form = $main::form;

  foreach my $table (qw(parts invoice orderitems rmaitems)) {
    my $base_query = "UPDATE $table SET unit = " .
      $dbh->quote($form->{"default_service_unit"}) . " " .
      "WHERE ((unit ISNULL) OR (unit = '')) AND ";
    my $query;

    if ($table eq "parts") {
      $query = "UPDATE $table SET unit = " .
        $dbh->quote($form->{"default_dimension_unit"}) . " " .
        "WHERE ((unit ISNULL) OR (unit = '')) AND " .
        "(assembly OR (inventory_accno_id > 0))";
    } else {
      $query = "UPDATE $table SET unit = " .
        $dbh->quote($form->{"default_dimension_unit"}) . " " .
        "WHERE ((unit ISNULL) OR (unit = '')) AND " .
        "parts_id IN (SELECT id FROM parts WHERE " .
        "(assembly OR (inventory_accno_id > 0)))";
    }

    $dbh->do($query) || mydberror($query);

    if ($table eq "parts") {
      $query = "UPDATE $table SET unit = " .
        $dbh->quote($form->{"default_service_unit"}) . " " .
        "WHERE ((unit ISNULL) OR (unit = '')) AND " .
        "((inventory_accno_id ISNULL) OR (inventory_accno_id = 0)) AND " .
        "NOT assembly";
    } else {
      $query = "UPDATE $table SET unit = " .
        $dbh->quote($form->{"default_service_unit"}) . " " .
        "WHERE ((unit ISNULL) OR (unit = '')) AND " .
        "parts_id IN (SELECT id FROM parts " .
        "WHERE ((inventory_accno_id ISNULL) OR (inventory_accno_id = 0)) " .
        "AND NOT assembly)";
    }

    $dbh->do($query) || mydberror($query);
  }
}

sub update_units {
  my $form = $main::form;

  my $res;

  print $form->parse_html_template("dbupgrade/units_header");

  if ($form->{"action2"} eq "add_unit") {
    $res = update_units_add_unit();
    return $res if ($res);

  } elsif ($form->{"action2"} eq "assign_units") {
    update_units_assign_units();

  } elsif ($form->{"action2"} eq "set_default") {
    update_units_set_default();

  }

  update_units_assign_known();

  $res = update_units_steps_1_2();
  return $res if ($res);

  return update_units_step_3();
}

update_units();
