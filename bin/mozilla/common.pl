#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
######################################################################
#
# Stuff that can be used from other modules
#
######################################################################

use Data::Dumper;

use SL::Common;

sub save_form {
  $lxdebug->enter_sub();

  my $old_form = "";
  map({ $old_form .= "$_=" . $form->escape($form->{$_}) . '&'; } keys(%{$form}));
  chop($old_form);

  $lxdebug->leave_sub();

  return $old_form;
}

sub restore_form {
  $lxdebug->enter_sub();

  my ($old_form) = @_;

  map({ delete($form->{$_}); } keys(%{$form}));

  foreach my $pair (split('&', $old_form)) {
    my ($key, $value) = split('=', $form->unescape($pair), 2);
    $form->{$key} = $value;
  }

  $lxdebug->leave_sub();
}

sub select_employee {
  $lxdebug->enter_sub();

  my ($callback_sub, @employees) = @_;

  if (0 == scalar(@employees)) {
    @employees = SystemBrace->get_all_employees(\%myconfig, $form);
  }

  my $old_form = save_form();

  $form->header();
  print($form->parse_html_template("generic/select_employee",
                                   { "EMPLOYEES" => \@employees,
                                     "old_form" => $old_form,
                                     "title" => $locale->text("Select an employee"),
                                     "nextsub" => "select_employee_internal",
                                     "callback_sub" => $callback_sub }));

  $lxdebug->leave_sub();
}

sub select_employee_internal {
  $lxdebug->enter_sub();

  my ($new_id, $new_name, $callback_sub);

  my $new_id = $form->{"new_id_" . $form->{"selection"}};
  my $new_name = $form->{"new_name_" . $form->{"selection"}};
  my $callback_sub = $form->{"callback_sub"};

  restore_form($form->{"old_form"});

  &{ $callback_sub }($new_id, $new_name);

  $lxdebug->leave_sub();
}

sub select_part {
  $lxdebug->enter_sub();

  my ($callback_sub, @parts) = @_;

  my $remap_parts_id = 0;
  if (defined($parts[0]->{"parts_id"}) && !defined($parts[0]->{"id"})) {
    $remap_parts_id = 1;
    map({ $_->{"id"} = $_->{"parts_id"}; } @parts);
  }

  my $remap_partnumber = 0;
  if (defined($parts[0]->{"partnumber"}) && !defined($parts[0]->{"number"})) {
    $remap_partnumber = 1;
    map({ $_->{"number"} = $_->{"partnumber"}; } @parts);
  }

  my $has_charge = 0;
  if (defined($parts[0]->{"chargenumber"})) {
    $has_charge = 1;
    map({ $_->{"has_charge"} = 1; } @parts);
  }

  my $old_form = save_form();

  $form->header();
  print($form->parse_html_template("generic/select_part",
                                   { "PARTS" => \@parts,
                                     "old_form" => $old_form,
                                     "title" => $locale->text("Select a part"),
                                     "nextsub" => "select_part_internal",
                                     "callback_sub" => $callback_sub,
                                     "has_charge" => $has_charge,
                                     "remap_parts_id" => $remap_parts_id,
                                     "remap_partnumber" => $remap_partnumber }));

  $lxdebug->leave_sub();
}

sub select_part_internal {
  $lxdebug->enter_sub();

  my ($new_item, $callback_sub);

  my $re = "^new_.*_" . $form->{"selection"};
  map({
    my $key = $_;
    $key =~ s/^new_//;
    $key =~ s/_\d+$//;
    $new_item->{$key} = $form->{$_};
  } grep(/$re/, keys(%{$form})));

  if ($form->{"remap_parts_id"}) {
    $new_item->{"parts_id"} = $new_item->{"id"};
    delete($new_item->{"id"});
  }
  if ($form->{"remap_partnumber"}) {
    $new_item->{"partnumber"} = $new_item->{"number"};
    delete($new_item->{"number"});
  }

  my $callback_sub = $form->{"callback_sub"};

  restore_form($form->{"old_form"});

  &{ $callback_sub }($new_item);

  $lxdebug->leave_sub();
}

sub part_selection_internal {
  $lxdebug->enter_sub();

  $order_by = "description";
  $order_by = $form->{"order_by"} if (defined($form->{"order_by"}));
  $order_dir = 1;
  $order_dir = $form->{"order_dir"} if (defined($form->{"order_dir"}));

  $parts = Common->retrieve_parts(\%myconfig, $form, $order_by, $order_dir);
  map({ $parts->[$_]->{"selected"} = $_ ? 0 : 1; } (0..$#{$parts}));
  if (0 == scalar(@{$parts})) {
    $form->show_generic_information($locale->text("No part was found matching the search parameters."));
  } elsif (1 == scalar(@{$parts})) {
    $onload = "part_selected('1')";
  }

  my $callback = "$form->{script}?action=part_selection_internal&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login path password partnumber description input_partnumber input_description input_partsid), grep({ /^[fl]_/ } keys %$form)));

  my @header_sort = qw(partnumber description);
  my %header_title = ( "partnumber" => $locale->text("Part Number"),
                       "description" => $locale->text("Part description"),
                       );

  my @header =
    map(+{ "column_title" => $header_title{$_},
           "column" => $_,
           "callback" => $callback . "order_by=${_}&order_dir=" . ($order_by eq $_ ? 1 - $order_dir : $order_dir),
         },
        @header_sort);

  $form->{"title"} = $locale->text("Select a part");
  $form->header();
  print($form->parse_html_template("generic/part_selection", { "HEADER" => \@header,
                                                               "PARTS" => $parts,
                                                               "onload" => $onload }));

  $lxdebug->leave_sub();
}

sub project_selection_internal {
  $lxdebug->enter_sub();

  $order_by = "description";
  $order_by = $form->{"order_by"} if (defined($form->{"order_by"}));
  $order_dir = 1;
  $order_dir = $form->{"order_dir"} if (defined($form->{"order_dir"}));

  $projects = Common->retrieve_projects(\%myconfig, $form, $order_by, $order_dir);
  map({ $projects->[$_]->{"selected"} = $_ ? 0 : 1; } (0..$#{$projects}));
  if (0 == scalar(@{$projects})) {
    $form->show_generic_information($locale->text("No project was found matching the search parameters."));
  } elsif (1 == scalar(@{$projects})) {
    $onload = "project_selected('1')";
  }

  my $callback = "$form->{script}?action=project_selection_internal&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login path password projectnumber description input_projectnumber input_description input_project_id), grep({ /^[fl]_/ } keys %$form)));

  my @header_sort = qw(projectnumber description);
  my %header_title = ( "projectnumber" => $locale->text("Project Number"),
                       "description" => $locale->text("Project description"),
                       );

  my @header =
    map(+{ "column_title" => $header_title{$_},
           "column" => $_,
           "callback" => $callback . "order_by=${_}&order_dir=" . ($order_by eq $_ ? 1 - $order_dir : $order_dir),
         },
        @header_sort);

  $form->{"title"} = $locale->text("Select a project");
  $form->header();
  print($form->parse_html_template("generic/project_selection", { "HEADER" => \@header,
                                                                  "PROJECTS" => $projects,
                                                                  "onload" => $onload }));

  $lxdebug->leave_sub();
}

sub employee_selection_internal {
  $lxdebug->enter_sub();

  $order_by = "name";
  $order_by = $form->{"order_by"} if (defined($form->{"order_by"}));
  $order_dir = 1;
  $order_dir = $form->{"order_dir"} if (defined($form->{"order_dir"}));

  $employees = Common->retrieve_employees(\%myconfig, $form, $order_by, $order_dir);
  map({ $employees->[$_]->{"selected"} = $_ ? 0 : 1; } (0..$#{$employees}));
  if (0 == scalar(@{$employees})) {
    $form->show_generic_information($locale->text("No employee was found matching the search parameters."));
  } elsif (1 == scalar(@{$employees})) {
    $onload = "employee_selected('1')";
  }

  my $callback = "$form->{script}?action=employee_selection_internal&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login path password name input_name input_id), grep({ /^[fl]_/ } keys %$form)));

  my @header_sort = qw(name);
  my %header_title = ( "name" => $locale->text("Name"),
                       );

  my @header =
    map(+{ "column_title" => $header_title{$_},
           "column" => $_,
           "callback" => $callback . "order_by=${_}&order_dir=" . ($order_by eq $_ ? 1 - $order_dir : $order_dir),
         },
        @header_sort);

  $form->{"title"} = $locale->text("Select an employee");
  $form->header();
  print($form->parse_html_template("generic/employee_selection", { "HEADER" => \@header,
                                                                   "EMPLOYEES" => $employees,
                                                                   "onload" => $onload }));

  $lxdebug->leave_sub();
}

sub delivery_customer_selection {
  $lxdebug->enter_sub();

  $order_by = "name";
  $order_by = $form->{"order_by"} if (defined($form->{"order_by"}));
  $order_dir = 1;
  $order_dir = $form->{"order_dir"} if (defined($form->{"order_dir"}));

  $delivery = Common->retrieve_delivery_customer(\%myconfig, $form, $order_by, $order_dir);
  map({ $delivery->[$_]->{"selected"} = $_ ? 0 : 1; } (0..$#{$delivery}));
  if (0 == scalar(@{$delivery})) {
    $form->show_generic_information($locale->text("No Customer was found matching the search parameters."));
  } elsif (1 == scalar(@{$delivery})) {
    $onload = "customer_selected('1')";
  }

  my $callback = "$form->{script}?action=delivery_customer_selection&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login path password name input_name input_id), grep({ /^[fl]_/ } keys %$form)));

  my @header_sort = qw(name customernumber address);
  my %header_title = ( "name" => $locale->text("Name"),
                       "customernumber" => $locale->text("Customer Number"),
                       "address" => $locale->text("Address"),
                     );

  my @header =
    map(+{ "column_title" => $header_title{$_},
           "column" => $_,
           "callback" => $callback . "order_by=${_}&order_dir=" . ($order_by eq $_ ? 1 - $order_dir : $order_dir),
         },
        @header_sort);

  $form->{"title"} = $locale->text("Select a Customer");
  $form->header();
  print($form->parse_html_template("generic/select_delivery_customer", { "HEADER" => \@header,
                                                                   "DELIVERY" => $delivery,
                                                                   "onload" => $onload }));

  $lxdebug->leave_sub();
}

sub vendor_selection {
  $lxdebug->enter_sub();

  $order_by = "name";
  $order_by = $form->{"order_by"} if (defined($form->{"order_by"}));
  $order_dir = 1;
  $order_dir = $form->{"order_dir"} if (defined($form->{"order_dir"}));

  $vendor = Common->retrieve_vendor(\%myconfig, $form, $order_by, $order_dir);
  map({ $vendor->[$_]->{"selected"} = $_ ? 0 : 1; } (0..$#{$vendor}));
  if (0 == scalar(@{$vendor})) {
    $form->show_generic_information($locale->text("No Vendor was found matching the search parameters."));
  } elsif (1 == scalar(@{$vendor})) {
    $onload = "vendor_selected('1')";
  }

  my $callback = "$form->{script}?action=vendor_selection&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login path password name input_name input_id), grep({ /^[fl]_/ } keys %$form)));

  my @header_sort = qw(name customernumber address);
  my %header_title = ( "name" => $locale->text("Name"),
                       "customernumber" => $locale->text("Customer Number"),
                       "address" => $locale->text("Address"),
                     );

  my @header =
    map(+{ "column_title" => $header_title{$_},
           "column" => $_,
           "callback" => $callback . "order_by=${_}&order_dir=" . ($order_by eq $_ ? 1 - $order_dir : $order_dir),
         },
        @header_sort);

  $form->{"title"} = $locale->text("Select a Customer");
  $form->header();
  print($form->parse_html_template("generic/select_vendor", { "HEADER" => \@header,
                                                                   "VENDOR" => $vendor,
                                                                   "onload" => $onload }));

  $lxdebug->leave_sub();
}

sub calculate_qty {
  $lxdebug->enter_sub();

  my @variable_sort = ();
  my %variable_list = ();
  my $unit_list = ();
  $form->{formel} =~ s/\r\n//g;

  my ($variable_string, $formel) = split /###/,$form->{formel};


  split /;/, $variable_string;
  foreach $item (@_) {
    my($name, $valueunit) = split /=/,$item;
    my($value, $unit) = split / /, $valueunit;

    push(@variable_sort, $value);
    $variable_list{$value} = $name;
    $unit_list{$value} = $unit;
  }

  my @header_sort = qw(variable value unit);
  my %header_title = ( "variable" => $locale->text("Variable"),
                       "value" => $locale->text("Value"),
                       "unit" => $locale->text("Unit"),
                     );

  my @variable = map(+{ "description" => $variable_list{$_},
                        "name" => $_,
                        "unit" => $unit_list{$_} }, @variable_sort);

  my @header =
    map(+{ "column_title" => $header_title{$_},
           "column" => $_,
         },
        @header_sort);
  $form->{formel} = $formel; 
  $form->{"title"} = $locale->text("Please enter values");
  $form->header();
  print($form->parse_html_template("generic/calculate_qty", { "HEADER" => \@header,
                                                                   "VARIABLES" => \@variable,
                                                                   "onload" => $onload }));

  $lxdebug->leave_sub();
}

sub calculate_alu {
  $lxdebug->enter_sub();

  my ($length, $weight) = split /\r\n/,$form->{formel};

  map({ $form->{$_} = "" } (qw(qty_alu price_alu total_alu qty_eloxal price_eloxal total_eloxal total)));

  if ($form->{description} =~ /.*Alupreisberechnung.*/) {
    $form->{description} =~ /.*Alupreisberechnung:\n(.*)kg Aluminiumprofil Einzelpreis: (.*) Gesamt: (.*)\n(.*)m Eloxal Einzelpreis: (.*) Gesamt: (.*)/;
    $form->{qty_alu} = $1;
    $form->{price_alu} = $2;
    $form->{total_alu} = $3;
    $form->{qty_eloxal} = $4;
    $form->{price_eloxal} = $5;
    $form->{total_eloxal} = $6;
    $form->{total} = $form->format_amount(\%myconfig, ($form->parse_amount(\%myconfig, $form->{total_alu}) + $form->parse_amount(\%myconfig, $form->{total_eloxal})));
  }
  ($form->{description}, $null) = split /\nAlupreisberechnung/, $form->{description};

  my $callback = "$form->{script}?action=vendor_selection&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login path password name input_name input_id), grep({ /^[fl]_/ } keys %$form)));

  my @header_sort = qw(name customernumber address);
  my %header_title = ( "name" => $locale->text("Name"),
                       "customernumber" => $locale->text("Customer Number"),
                       "address" => $locale->text("Address"),
                     );
  ($null, $form->{weight}) = split / /, $weight;
  ($null, $form->{length}) = split / /, $length;

  $form->{calc_weight} = $form->parse_amount(\%myconfig, $form->{weight});
  $form->{calc_length} = $form->parse_amount(\%myconfig, $form->{length});


  my @header =
    map(+{ "column_title" => $header_title{$_},
           "column" => $_,
         },
        @header_sort);

  $form->{"title"} = $locale->text("Enter values for aluminium calculation");
  $form->header();
  print($form->parse_html_template("generic/calculate_alu"));

  $lxdebug->leave_sub();
}


sub set_longdescription {
  $lxdebug->enter_sub();


  my $callback = "$form->{script}?action=set_longdescription&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login path password name input_name input_id), grep({ /^[fl]_/ } keys %$form)));

  $form->{"title"} = $locale->text("Enter longdescription");
  $form->header();
  print($form->parse_html_template("generic/set_longdescription"));

  $lxdebug->leave_sub();
}

1;
