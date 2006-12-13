#!/usr/bin/perl

# Datenbankupgrade: Einfuehrung von Buchungsgruppen

die("This script cannot be run from the command line.") unless ($main::form);

sub mydberror {
  my ($msg) = @_;
  die($dbup_locale->text("Database update error:") .
      "<br>$msg<br>" . $DBI::errstr);
}

sub mydoquery {
  my ($query, @values) = @_;

  $dbh->do($query, undef, @values) ||
    mydberror($query . " (" . join(", ", @values) . ")");
}

sub set_taxzone_ids {
  foreach my $table (qw(customer vendor ar ap oe)) {
    my $query = "UPDATE ${table} SET taxzone_id = 0";
    $dbh->do($query) || mydberror($query);
  }
}

sub set_ic_links {
  my $query =
    "SELECT id, link " .
    "FROM chart " .
    "WHERE id IN " .
    "  (SELECT DISTINCT inventory_accno_id " .
    "   FROM parts " .
    "   WHERE (NOT inventory_accno_id ISNULL) AND (inventory_accno_id > 0))";

  my $sth = $dbh->prepare($query);
  $sth->execute() || mydberror($query);

  my $query_update = "UPDATE chart SET link = ? WHERE id = ?";
  my $sth_update = $dbh->prepare($query_update);

  while (my $ref = $sth->fetchrow_hashref()) {
    my %links;
    map({ $links{$_} = 1 } split(/:/, $ref->{"link"}));
    $links{"IC"} = 1;
    my $new_link = join(":", keys(%links));
    $sth_update->execute($new_link, $ref->{"id"}) ||
      mydberror($query_update . " ($new_link, $ref->{id})");
  }

  $sth->finish();
  $sth_update->finish();
}

sub force_inventory_accno_id_for_parts {
  my $query =
    "SELECT inventory_accno_id " .
    "FROM buchungsgruppen " .
    "WHERE description = 'Standard 16%'";

  my ($bg_id) = $dbh->selectrow_array($query);

  if ($bg_id) {
    $query =
      "UPDATE parts SET inventory_accno_id = $bg_id " .
      "WHERE (NOT inventory_accno_id ISNULL) AND (inventory_accno_id > 0)";
    $dbh->do($query) || mydberror($query);
  }
}

sub retrieve_accounts {
  my $query =
    "SELECT c.accno, c.description, c.link, c.id, " .
    "d.inventory_accno_id, d.income_accno_id, d.expense_accno_id " .
    "FROM chart c, defaults d " .
    "WHERE c.link LIKE '%IC%' " .
    "ORDER BY c.accno";

  my $sth = $dbh->prepare($query);
  $sth->execute() || mydberror($query);

  my ($acc_inventory, $acc_income, $acc_expense) = ({}, {}, {});
  my %key_map = (
    "IC" => $acc_inventory,
    "IC_income" => $acc_income,
    "IC_sale" => $acc_income,
    "IC_expense" => $acc_expense,
    "IC_cogs" => $acc_expense,
    );

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split(/:/, $ref->{link})) {
      next unless ($key_map{$key});
      $key_map{$key}->{$ref->{"id"}} = {
        "accno" => $ref->{"accno"},
        "description" => $ref->{"description"},
        "id" => $ref->{"id"},
        "selected" => ($ref->{id} eq $ref->{inventory_accno_id})
          || ($ref->{id} eq $ref->{income_accno_id})
          || ($ref->{id} eq $ref->{expense_accno_id}) ?
          "selected" : "",
      };
    }
  }
  $sth->finish();

  $acc_inventory =
    [sort({ $a->{"accno"} cmp $b->{"accno"} } values(%{$acc_inventory}))];
  $acc_income =
    [sort({ $a->{"accno"} cmp $b->{"accno"} } values(%{$acc_income}))];
  $acc_expense =
    [sort({ $a->{"accno"} cmp $b->{"accno"} } values(%{$acc_expense}))];

  return ($acc_inventory, $acc_income, $acc_expense);
}

sub retrieve_buchungsgruppen {
  my @buchungsgruppen;

  my $query =
    "SELECT bg.*, " .
    "  ci.accno AS inventory_accno, " .
    "  ci0.accno AS income_accno_0, " .
    "  ce0.accno AS expense_accno_0, " .
    "  ci1.accno AS income_accno_1, " .
    "  ce1.accno AS expense_accno_1, " .
    "  ci2.accno AS income_accno_2, " .
    "  ce2.accno AS expense_accno_2, " .
    "  ci3.accno AS income_accno_3, " .
    "  ce3.accno AS expense_accno_3 " .
    "FROM buchungsgruppen bg " .
    "LEFT JOIN chart ci ON bg.inventory_accno_id = ci.id " .
    "LEFT JOIN chart ci0 ON bg.income_accno_id_0 = ci0.id " .
    "LEFT JOIN chart ce0 ON bg.expense_accno_id_0 = ce0.id " .
    "LEFT JOIN chart ci1 ON bg.income_accno_id_1 = ci1.id " .
    "LEFT JOIN chart ce1 ON bg.expense_accno_id_1 = ce1.id " .
    "LEFT JOIN chart ci2 ON bg.income_accno_id_2 = ci2.id " .
    "LEFT JOIN chart ce2 ON bg.expense_accno_id_2 = ce2.id " .
    "LEFT JOIN chart ci3 ON bg.income_accno_id_3 = ci3.id " .
    "LEFT JOIN chart ce3 ON bg.expense_accno_id_3 = ce3.id";
  my $sth = $dbh->prepare($query);
  $sth->execute() || mydberror($query);

  while (my $ref = $sth->fetchrow_hashref()) {
    push(@buchungsgruppen, $ref);
  }
  $sth->finish();

  return \@buchungsgruppen;
}

sub update_known_buchungsgruppen {
  my ($buchungsgruppen) = @_;

  my @updates;

  my $query =
    "SELECT id, inventory_accno_id, income_accno_id, expense_accno_id " .
    "FROM parts " .
    "WHERE NOT inventory_accno_id ISNULL AND (inventory_accno_id > 0) ";
  my $sth = $dbh->prepare($query);
  $sth->execute() || mydberror($query);

  my $query_update = "UPDATE parts SET buchungsgruppen_id = ?";
  $query_update .= ", inventory_accno_id = ?" if ($main::eur);
  $query_update .= " WHERE id = ?";
  my $sth_update = $dbh->prepare($query_update);

  while (my $ref = $sth->fetchrow_hashref()) {
    foreach my $bg (@{$buchungsgruppen}) {
      if (($main::eur ||
           ($ref->{"inventory_accno_id"} == $bg->{"inventory_accno_id"})) &&
          ($ref->{"income_accno_id"} == $bg->{"income_accno_id_0"}) &&
          ($ref->{"expense_accno_id"} == $bg->{"expense_accno_id_0"})) {
        my @values = ($bg->{"id"}, $ref->{"id"});
        splice(@values, 1, 0, $bg->{"inventory_accno_id"}) if ($main::eur);
        $sth_update->execute(@values) ||
          mydberror($query_update . " (" . join(", ", @values) . ")");
        last;
      }
    }
  }
  $sth->finish();

  my $query =
    "SELECT id, inventory_accno_id, income_accno_id, expense_accno_id " .
    "FROM parts " .
    "WHERE (inventory_accno_id ISNULL OR (inventory_accno_id = 0)) AND " .
    " NOT assembly";
  my $sth = $dbh->prepare($query);
  $sth->execute() || mydberror($query);

  while (my $ref = $sth->fetchrow_hashref()) {
    foreach my $bg (@{$buchungsgruppen}) {
      if (($ref->{"income_accno_id"} == $bg->{"income_accno_id_0"}) &&
          ($ref->{"expense_accno_id"} == $bg->{"expense_accno_id_0"})) {
        my @values = ($bg->{"id"}, $ref->{"id"});
        splice(@values, 1, 0, undef) if ($main::eur);
        $sth_update->execute(@values) ||
          mydberror($query_update . " (" . join(", ", @values) . ")");
        last;
      }
    }
  }
  $sth->finish();
  $sth_update->finish();
}

sub retrieve_unknown_accno_combinations {
  my ($buchungsgruppen) = @_;

  my (@parts, @services, @assemblies, $sth, $query, $ref);

  $query =
    "SELECT DISTINCT " .
    "p.inventory_accno_id, p.income_accno_id, p.expense_accno_id, " .
    "c1.accno AS inventory_accno, c1.description AS inventory_description, " .
    "c2.accno AS income_accno, c2.description AS income_description, " .
    "c3.accno AS expense_accno, c3.description AS expense_description " .
    "FROM parts p " .
    "LEFT JOIN chart c1 ON p.inventory_accno_id = c1.id " .
    "LEFT JOIN chart c2 ON p.income_accno_id = c2.id " .
    "LEFT JOIN chart c3 ON p.expense_accno_id = c3.id " .
    "WHERE NOT inventory_accno_id ISNULL AND (inventory_accno_id > 0)";

  $sth = $dbh->prepare($query);
  $sth->execute() || mydberror($query);

  while ($ref = $sth->fetchrow_hashref()) {
    my $found = 0;

    foreach my $bg (@{$buchungsgruppen}) {
      if (($ref->{"inventory_accno_id"} == $bg->{"inventory_accno_id"}) &&
          ($ref->{"income_accno_id"} == $bg->{"income_accno_id_0"}) &&
          ($ref->{"expense_accno_id"} == $bg->{"expense_accno_id_0"})) {
        $found = 1;
        last;
      }
    }

    push(@parts, $ref) unless ($found);
  }
  $sth->finish();

  $query =
    "SELECT DISTINCT " .
    "p.income_accno_id, p.expense_accno_id, " .
    "c2.accno AS income_accno, c2.description AS income_description, " .
    "c3.accno AS expense_accno, c3.description AS expense_description " .
    "FROM parts p " .
    "LEFT JOIN chart c2 ON p.income_accno_id = c2.id " .
    "LEFT JOIN chart c3 ON p.expense_accno_id = c3.id " .
    "WHERE (inventory_accno_id ISNULL OR (inventory_accno_id = 0)) AND " .
    " NOT assembly";

  $sth = $dbh->prepare($query);
  $sth->execute() || mydberror($query);

  while ($ref = $sth->fetchrow_hashref()) {
    my $found = 0;

    foreach my $bg (@{$buchungsgruppen}) {
      if (($ref->{"income_accno_id"} == $bg->{"income_accno_id_0"}) &&
          ($ref->{"expense_accno_id"} == $bg->{"expense_accno_id_0"})) {
        $found = 1;
        last;
      }
    }

    push(@services, $ref) unless ($found);
  }
  $sth->finish();

  $query =
    "SELECT DISTINCT " .
    "p.income_accno_id, " .
    "c.accno AS income_accno, c.description AS income_description " .
    "FROM parts p " .
    "LEFT JOIN chart c ON p.income_accno_id = c.id " .
    "WHERE p.assembly AND " .
    " (p.buchungsgruppen_id ISNULL OR (p.buchungsgruppen_id = 0))";

  $sth = $dbh->prepare($query);
  $sth->execute() || mydberror($query);

  while ($ref = $sth->fetchrow_hashref()) {
    push(@assemblies, $ref);
  }

  return (\@parts, \@services, \@assemblies);
}

sub display_create_bgs_dialog {
  my ($type, $list,
      $acc_inventory, $acc_income, $acc_expense,
      $buchungsgruppen) = @_;

  foreach my $entry (@{$list}) {
    $entry->{"ACC_INVENTORY"} = $acc_inventory;
    $entry->{"ACC_INCOME"} = $acc_income;
    $entry->{"ACC_EXPENSE"} = $acc_expense;
    $entry->{"eur"} = $main::eur;
  }

  # $form->parse_html_template("dbupgrade/buchungsgruppen_parts")
  # $form->parse_html_template("dbupgrade/buchungsgruppen_services")
  # $form->parse_html_template("dbupgrade/buchungsgruppen_assemblies")

  print($form->parse_html_template("dbupgrade/buchungsgruppen_${type}",
                                   { "LIST" => $list,
                                     "BUCHUNGSGRUPPEN" => $buchungsgruppen,
                                   }));
}

sub create_buchungsgruppen {
  my $form = $main::form;

  for (my $i = 1; $i <= $form->{"rowcount"}; $i++) {
    next unless ($form->{"description_$i"} &&
                 $form->{"inventory_accno_id_$i"} &&
                 $form->{"income_accno_id_0_$i"} &&
                 $form->{"expense_accno_id_0_$i"} &&
                 $form->{"income_accno_id_1_$i"} &&
                 $form->{"expense_accno_id_1_$i"} &&
                 $form->{"income_accno_id_2_$i"} &&
                 $form->{"expense_accno_id_2_$i"} &&
                 $form->{"income_accno_id_3_$i"} &&
                 $form->{"expense_accno_id_3_$i"});

    my $query = "SELECT nextval('id')";
    my ($id) = $dbh->selectrow_array($query);
    $query =
      "INSERT INTO buchungsgruppen (" .
      "id, description, inventory_accno_id, " .
      "income_accno_id_0, expense_accno_id_0, " .
      "income_accno_id_1, expense_accno_id_1, " .
      "income_accno_id_2, expense_accno_id_2, " .
      "income_accno_id_3, expense_accno_id_3) " .
      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    my @values = ($id, $form->{"description_$i"});

    foreach my $acc (qw(inventory_accno_id
                        income_accno_id_0 expense_accno_id_0
                        income_accno_id_1 expense_accno_id_1
                        income_accno_id_2 expense_accno_id_2
                        income_accno_id_3 expense_accno_id_3)) {
      push(@values, (split(/--/, $form->{"${acc}_${i}"}))[0]);
    }

    mydoquery($query, @values);

    $form->{"new_buchungsgruppen_id_$i"} = $id;
  }

  $dbh->commit();
  $dbh->begin_work();
}

sub assign_buchungsgruppen_for_assemblies {
  my ($query, $sth, $i);

  $query =
    "UPDATE parts " .
    "SET buchungsgruppen_id = ? " .
    "WHERE assembly AND " .
    "(buchungsgruppen_id ISNULL OR (buchungsgruppen_id = 0)) AND " .
    "(income_accno_id = ?)";
  $sth = $dbh->prepare($query);

  for ($i = 1; $i <= $form->{"rowcount"}; $i++) {
    next unless ($form->{"new_buchungsgruppen_id_$i"});

    my @values = ($form->{"new_buchungsgruppen_id_$i"},
                  $form->{"income_accno_id_0_$i"});
    $sth->execute(@values) ||
      mydberror($query . " (" . join(", ", @values) . ")");
  }

  $sth->finish();

  $dbh->commit();
  $dbh->begin_work();
}

sub retrieve_std_inventory_accno_id {
  my $query;

  $query = "SELECT coa FROM defaults";
  my ($coa) = $dbh->selectrow_array($query);

  my $inventory_accno;

  if ($coa eq "Germany-DATEV-SKR03EU") {
    $inventory_accno = "3980";

  } elsif ($coa eq "Germany-DATEV-SKR04EU") {
    $inventory_accno = "1140";
  }

  my $inventory_accno_id;
  if ($inventory_accno) {
    $query = "SELECT id FROM chart WHERE accno = $inventory_accno";
    ($inventory_accno_id) = $dbh->selectrow_array($query);
  }

  if (!$inventory_accno_id) {
    $query = "SELECT id, link FROM chart WHERE link LIKE '%IC%'";
    my $sth = $dbh->prepare($query);
    $sth->execute() || mydberror($query);

    while (my $ref = $sth->fetchrow_hashref()) {
      if (grep({ $_ eq "IC" } split(/:/, $ref->{"link"}))) {
        $inventory_accno_id = $ref->{"id"};
        last;
      }
    }
    $sth->finish();
  }

  $inventory_accno_id = 1 unless ($inventory_accno_id);

  $form->{"std_inventory_accno_id"} = $inventory_accno_id;
}

sub do_update {
  if ($main::form->{"action2"} eq "create_buchungsgruppen") {
    create_buchungsgruppen();
  }

  if ($main::form->{"action2"} eq "create_buchungsgruppen_assemblies") {
    create_buchungsgruppen();
    assign_buchungsgruppen_for_assemblies();
  }

  retrieve_std_inventory_accno_id();

  # Set all taxzone_id columns = 0.
  set_taxzone_ids();

  # If balancing is off then force parts.inventory_accno_id to
  # a single value for parts.
  force_inventory_accno_id_for_parts() if ($main::eur);

  # Force "IC" to be present in chart.link for all accounts
  # which have been used as inventory accounts in parts.
  set_ic_links();

  # Assign buchungsgruppen_ids in parts for known combinations
  # of inventory_accno_id, income_accno_id, expense_accno_id.
  my $buchungsgruppen = retrieve_buchungsgruppen();

  update_known_buchungsgruppen($buchungsgruppen);

  # Retrieve all distinct combinations of inventory_accno_id,
  # income_accno_id and expense_accno_id for which there's no
  # Buchungsgruppe. Then let the user create new ones.
  ($parts, $services, $assemblies) =
    retrieve_unknown_accno_combinations($buchungsgruppen);

  my ($acc_inventory, $acc_income, $acc_expense) = retrieve_accounts();

  print($form->parse_html_template("dbupgrade/buchungsgruppen_header"));

  if (scalar(@{$parts})) {
    display_create_bgs_dialog("parts", $parts,
                              $acc_inventory, $acc_income, $acc_expense,
                              $buchungsgruppen);
    return 2;
  } else {
    print($form->parse_html_template("dbupgrade/buchungsgruppen_parts_done"));
  }

  if (scalar(@{$services})) {
    display_create_bgs_dialog("services", $services,
                              $acc_inventory, $acc_income, $acc_expense,
                              $buchungsgruppen);
    return 2;
  } else {
    print($form->parse_html_template("dbupgrade/buchungsgruppen_services_done"));
  }

  if (scalar(@{$assemblies})) {
    display_create_bgs_dialog("assemblies", $assemblies,
                              $acc_inventory, $acc_income, $acc_expense,
                              $buchungsgruppen);
    return 2;
  } else {
    print($form->parse_html_template("dbupgrade/buchungsgruppen_assemblies_done"));
  }

  print($form->parse_html_template("dbupgrade/buchungsgruppen_footer"));

  return 1;
}

return do_update();
