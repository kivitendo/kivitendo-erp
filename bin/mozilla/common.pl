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

use SL::Common;
use SL::DBUtils;
use SL::Form;
use SL::MoreCommon;

sub build_std_url {
  $lxdebug->enter_sub(2);

  my $script = $form->{script};

  my @parts;

  foreach my $key (@_) {
    next unless ($key);

    if ($key =~ /(.*?)=(.*)/) {
      if ($1 eq 'script') {
        $script = $2;
      } else {
        push @parts, $key;
      }

    } else {
      foreach my $var ($form->flatten_variables($key)) {
        push @parts, E($var->{key}) . '=' . E($var->{value});
      }
    }
  }

  my $url = "${script}?" . join('&', @parts);

  $lxdebug->leave_sub(2);

  return $url;
}

# -------------------------------------------------------------------------

## Customers/Vendors

sub check_customer_or_vendor {
  $lxdebug->enter_sub();

  my ($field, $cov_selected_nextsub, $is_vendor) = @_;

  if ($form->{"f_${field}"} eq $form->{"f_old_${field}"}) {
    $lxdebug->leave_sub();
    return 1;
  }

  my $type = $is_vendor ? $locale->text("vendor") : $locale->text("customer");

  my $old_form = save_form();
  $form->{"name"} = $form->{"f_${field}"};
  $form->{"obsolete"} = 1;
  my $covs;
  $covs = Common->retrieve_customers_or_vendors(\%myconfig, $form, "name", 1, $is_vendor);
  restore_form($old_form);

  if (0 == scalar(@{$covs})) {
    $form->header();
    $form->show_generic_error(sprintf($locale->text("There is no %s whose name matches '%s'."), $type, $form->{"f_${field}"}));

    $lxdebug->leave_sub();
    return 0;

  }

  if (1 != scalar(@{$covs})) {
    # If there is more than one CoV with the same name
    # then we have to check if the ID is set, too. Otherwise
    # we'd be stuck in an endless loop.
    if ($form->{"f_${field}_id"}) {
      foreach my $cov (@{$covs}) {
        if (($form->{"f_${field}_id"} == $cov->{"id"}) &&
            ($form->{"f_${field}"} eq $cov->{"name"})) {
          $lxdebug->leave_sub();
          return 1;
        }
      }
    }

    $form->{"cov_selected_nextsub"} = $cov_selected_nextsub;
    $form->{"check_cov_field"} = $field;
    select_customer_or_vendor("cov_selected", $is_vendor, @{$covs});
    $lxdebug->leave_sub();
    return 0;
  }

  $form->{"f_${field}_id"} = $covs->[0]->{"id"};
  $form->{"f_${field}"} = $covs->[0]->{"name"};

  $lxdebug->leave_sub();

  return 1;
}

sub select_customer_or_vendor {
  $lxdebug->enter_sub();

  my ($callback_sub, $is_vendor, @covs) = @_;

  my $old_form = save_form();

  if (0 == scalar(@covs)) {
    delete($form->{"name"});
    $form->{"obsolete"} = 1;
    my $c = Common->retrieve_customers_or_vendors(\%myconfig, $form, "name", 1, $is_vendor);
    restore_form($old_form);
    @covs = @{$c};
  }

  $form->header();
  print($form->parse_html_template("generic/select_customer_or_vendor",
                                   { "COVS" => \@covs,
                                     "old_form" => $old_form,
                                     "title" => $is_vendor ? $locale->text("Select a vendor") : $locale->text("Select a customer"),
                                     "nextsub" => "select_cov_internal",
                                     "callback_sub" => $callback_sub }));

  $lxdebug->leave_sub();
}

sub cov_selected {
  $lxdebug->enter_sub();
  my ($new_id, $new_name) = @_;

  my $field = $form->{"check_cov_field"};
  delete($form->{"check_cov_field"});

  $form->{"f_${field}_id"} = $new_id;
  $form->{"f_${field}"} = $new_name;
  $form->{"f_old_${field}"} = $new_name;

  &{ $form->{"cov_selected_nextsub"} }();

  $lxdebug->leave_sub();
}

sub select_cov_internal {
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
  print $form->parse_html_template("generic/select_part",
                                   { "PARTS"            => \@parts,
                                     "old_form"         => $old_form,
                                     "title"            => $locale->text("Select a part"),
                                     "nextsub"          => "select_part_internal",
                                     "callback_sub"     => $callback_sub,
                                     "has_charge"       => $has_charge,
                                     "remap_parts_id"   => $remap_parts_id,
                                     "remap_partnumber" => $remap_partnumber });

  $lxdebug->leave_sub();
}

sub select_part_internal {
  $lxdebug->enter_sub();

  my ($new_item, $callback_sub);

  my $re = "^new_.*_" . $form->{"selection"};

  foreach (grep /$re/, keys %{ $form }) {
    my $new_key           =  $_;
    $new_key              =~ s/^new_//;
    $new_key              =~ s/_\d+$//;
    $new_item->{$new_key} =  $form->{$_};
  }

  if ($form->{remap_parts_id}) {
    $new_item->{parts_id} = $new_item->{id};
    delete $new_item->{id};
  }

  if ($form->{remap_partnumber}) {
    $new_item->{partnumber} = $new_item->{number};
    delete $new_item->{number};
  }

  my $callback_sub = $form->{callback_sub};

  restore_form($form->{old_form});

  call_sub($callback_sub, $new_item);

  $lxdebug->leave_sub();
}

sub part_selection_internal {
  $lxdebug->enter_sub();

  $order_by  = "description";
  $order_by  = $form->{"order_by"} if (defined($form->{"order_by"}));
  $order_dir = 1;
  $order_dir = $form->{"order_dir"} if (defined($form->{"order_dir"}));

  %options   = map { $_ => 1 } split m/:/, $form->{options};

  map { $form->{$_} = 1 if ($options{$_}) } qw(no_services no_assemblies stockable);

  $parts = Common->retrieve_parts(\%myconfig, $form, $order_by, $order_dir);
  map({ $parts->[$_]->{"selected"} = $_ ? 0 : 1; } (0..$#{$parts}));
  if (0 == scalar(@{$parts})) {
    $form->show_generic_information($locale->text("No part was found matching the search parameters."));
  } elsif (1 == scalar(@{$parts})) {
    $onload = "part_selected('1')";
  }

  my $callback = "$form->{script}?action=part_selection_internal&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(partnumber description input_partnumber input_description input_partsid), grep({ /^[fl]_/ } keys %$form)));

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
  print $form->parse_html_template("generic/part_selection", { "HEADER" => \@header,
                                                               "PARTS"  => $parts,
                                                               "onload" => $onload });

  $lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub project_selection_internal {
  $lxdebug->enter_sub();

  $auth->check_right($form->{login}, 'project_edit');

  my %valid_order_by_fields = ('description' => 1, 'projectnumber' => 1);

  $order_by  = "description";
  $order_by  = $form->{order_by} if ($valid_order_by_fields{$form->{order_by}});
  $order_dir = !defined $form->{order_dir} ? 1 : $form->{order_dir} ? 1 : 0;

  $projects  = Common->retrieve_projects(\%myconfig, $form, $order_by, $order_dir);

  if (1 == scalar @{ $projects }) {
    $onload = "project_selected('1')";
  }

  my $callback = build_std_url('action=project_selection_internal', qw(projectnumber description input_projectnumber input_description input_project_id),
                               grep { /^[fl]_/ } keys %{ $form });

  my @header_sort  = qw(projectnumber description);
  my %header_title = ( "projectnumber" => $locale->text("Project Number"),
                       "description"   => $locale->text("Project description"),
                       );

  my @header =
    map(+{ "column_title" => $header_title{$_},
           "column"       => $_,
           "callback"     => $callback . "&order_by=${_}&order_dir=" . ($order_by eq $_ ? 1 - $order_dir : $order_dir),
         },
        @header_sort);

  $form->{title} = $locale->text("Select a project");
  $form->header();
  print $form->parse_html_template("generic/project_selection", { "HEADER"   => \@header,
                                                                  "PROJECTS" => $projects,
                                                                  "onload"   => $onload });

  $lxdebug->leave_sub();
}

sub new_project {
  $lxdebug->enter_sub();

  delete @{$form}{qw(action login password)};

  my $callback = build_std_url('action=project_created', grep { '' eq ref $form->{$_} } keys %{ $form });

  my $argv = "action=add&type=project&callback=" . E($callback);

  exec("perl", "pe.pl", $argv);
}

sub project_created {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text("Select a project");
  $form->header();

  my $args = {
    'PROJECTS' => [ { map { $_ => $form->{"new_$_"} } qw(id projectnumber description) } ],
    'HEADER'   => [],
    'onload'   => "project_selected('1')",
  };

  print $form->parse_html_template("generic/project_selection", $args);

  $lxdebug->leave_sub();
}

sub project_selection_check {
  $lxdebug->enter_sub();

  my ($id_field, $number_field, $description_field, $project_selected_nextsub, $prefix) = @_;

  $prefix = "f_" unless defined($prefix);

  if (!$form->{"${prefix}${number_field}"} &&
      (!$description_field || !$form->{"${prefix}${description_field}"})) {
    delete $form->{"${prefix}${id_field}"};
    delete $form->{"${prefix}old_${number_field}"};
    delete $form->{"${prefix}old_${description_field}"} if ($description_field);

    $lxdebug->leave_sub();
    return 1;
  }

  if (($form->{"${prefix}${number_field}"}      eq $form->{"${prefix}old_${number_field}"}) &&
      (!$description_field ||
       (($form->{"${prefix}${description_field}"} eq $form->{"${prefix}old_${description_field}"})))) {
    $lxdebug->leave_sub();
    return 1;
  }

  my $old_form = save_form();

  $form->{projectnumber} = $form->{"${prefix}${number_field}"};
  $form->{full_search}   = 1;

  if ($description_field) {
    $form->{description} = $form->{"${prefix}${description_field}"};
  } else {
    delete $form->{description};
  }

  my $projects = Common->retrieve_projects(\%myconfig, $form, "projectnumber", 1);
  restore_form($old_form);

  if (0 == scalar @{$projects}) {
    $form->error(sprintf($locale->text("There is no project whose project number matches '%s'."), $form->{"${prefix}${number_field}"}));

    $lxdebug->leave_sub();
    return 0;
  }

  if (1 != scalar(@{$projects})) {
    $form->{project_selected_nextsub}        = $project_selected_nextsub;
    $form->{check_project_id_field}          = $id_field;
    $form->{check_project_number_field}      = $number_field;
    $form->{check_project_description_field} = $description_field;

    project_selection("project_selection_selected", $prefix, @{ $projects });

    $lxdebug->leave_sub();
    return 0;
  }

  $form->{"${prefix}${id_field}"}         = $projects->[0]->{id};
  $form->{"${prefix}${number_field}"}     = $projects->[0]->{projectnumber};
  $form->{"${prefix}old_${number_field}"} = $projects->[0]->{projectnumber};

  if ($description_field) {
    $form->{"${prefix}${description_field}"}     = $projects->[0]->{description};
    $form->{"${prefix}old_${description_field}"} = $projects->[0]->{description};
  }

  $lxdebug->leave_sub();

  return 1;
}

sub project_selection {
  $lxdebug->enter_sub();

  my ($callback_sub, $prefix, @projects) = @_;

  if (0 == scalar @projects) {
    my $old_form = save_form();
    map { delete($form->{$_}); } qw(projectnumber description);

    @projects = @{ Common->retrieve_projects(\%myconfig, $form, "projectnumber", 1) };

    restore_form($old_form);
  }

  $form->header();
  print $form->parse_html_template("generic/select_project",
                                   { "PROJECTS"     => \@projects,
                                     "old_form"     => save_form(qw(login password)),
                                     "title"        => $locale->text("Select an project"),
                                     "nextsub"      => "project_selection_step2",
                                     "prefix"       => $prefix,
                                     "callback_sub" => $callback_sub });

  $lxdebug->leave_sub();
}

sub project_selection_step2 {
  $lxdebug->enter_sub();

  my ($new_id, $new_name, $callback_sub);

  my $new_id          = $form->{"new_id_"          . $form->{selection}};
  my $new_number      = $form->{"new_number_"      . $form->{selection}};
  my $new_description = $form->{"new_description_" . $form->{selection}};
  my $callback_sub    = $form->{callback_sub};
  my $prefix          = $form->{prefix};

  restore_form($form->{old_form}, 0, qw(login password));
  delete $form->{header};

  call_sub($callback_sub, $new_id, $new_number, $new_description, $prefix);

  $lxdebug->leave_sub();
}

sub project_selection_selected {
  $lxdebug->enter_sub();

  my ($new_id, $new_number, $new_description, $prefix) = @_;

  my ($id_field, $number_field, $description_field)    = ($form->{check_project_id_field}, $form->{check_project_number_field}, $form->{check_project_description_field});

  map { delete $form->{"check_project_${_}_field"} } qw(id number description);

  $form->{"${prefix}${id_field}"}         = $new_id;
  $form->{"${prefix}${number_field}"}     = $new_number;
  $form->{"${prefix}old_${number_field}"} = $new_number;

  if ($description_field) {
    $form->{"${prefix}${description_field}"}     = $new_description;
    $form->{"${prefix}old_${description_field}"} = $new_description;
  }

  call_sub($form->{project_selected_nextsub});

  $lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

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
      (qw(name input_name input_id), grep({ /^[fl]_/ } keys %$form)));

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

# -------------------------------------------------------------------------

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
      (qw(name input_name input_id), grep({ /^[fl]_/ } keys %$form)));

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
  print $form->parse_html_template("generic/select_delivery_customer", { "HEADER"   => \@header,
                                                                         "DELIVERY" => $delivery,
                                                                         "onload"   => $onload });

  $lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

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
      (qw(name input_name input_id), grep({ /^[fl]_/ } keys %$form)));

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
  print $form->parse_html_template("generic/select_vendor", { "HEADER" => \@header,
                                                              "VENDOR" => $vendor,
                                                              "onload" => $onload });

  $lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub calculate_qty {
  $lxdebug->enter_sub();

  my @variable_sort = ();
  my %variable_list = ();
  my $unit_list = ();
  $form->{formel} =~ s/\r\n//g;

  my ($variable_string, $formel) = split /###/,$form->{formel};


  split m/;/, $variable_string;
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
  print($form->parse_html_template("generic/calculate_qty", { "HEADER"    => \@header,
                                                              "VARIABLES" => \@variable,
                                                              "onload"    => $onload }));

  $lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub set_longdescription {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text("Enter longdescription");
  $form->header();
  print $form->parse_html_template("generic/set_longdescription");

  $lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub H {
  return $form->quote_html($_[0]);
}

sub Q {
  return $form->quote($_[0]);
}

sub E {
  return $form->escape($_[0]);
}

sub NTI {
  my ($element) = @_;

  $element =~ s/tabindex\s*=\s*"\d+"//;
  return $element;
}

sub format_dates {
  $lxdebug->enter_sub();

  my ($dateformat, $longformat, @indices) = @_;

  $dateformat = $myconfig{"dateformat"} unless ($dateformat);

  foreach my $idx (@indices) {
    next unless (defined($form->{$idx}));

    if (!ref($form->{$idx})) {
      $form->{$idx} = $locale->reformat_date(\%myconfig, $form->{$idx},
                                             $dateformat, $longformat);

    } elsif (ref($form->{$idx}) eq "ARRAY") {
      for (my $i = 0; $i < scalar(@{$form->{$idx}}); $i++) {
        $form->{$idx}->[$i] =
          $locale->reformat_date(\%myconfig, $form->{$idx}->[$i],
                                 $dateformat, $longformat);
      }
    }
  }

  $lxdebug->leave_sub();
}

sub reformat_numbers {
  $lxdebug->enter_sub();

  my ($numberformat, $places, @indices) = @_;

  return $lxdebug->leave_sub()
    if (!$numberformat || ($numberformat eq $myconfig{"numberformat"}));

  foreach my $idx (@indices) {
    next unless (defined($form->{$idx}));

    if (!ref($form->{$idx})) {
      $form->{$idx} = $form->parse_amount(\%myconfig, $form->{$idx});

    } elsif (ref($form->{$idx}) eq "ARRAY") {
      for (my $i = 0; $i < scalar(@{$form->{$idx}}); $i++) {
        $form->{$idx}->[$i] =
          $form->parse_amount(\%myconfig, $form->{$idx}->[$i]);
      }
    }
  }

  my $saved_numberformat = $myconfig{"numberformat"};
  $myconfig{"numberformat"} = $numberformat;

  foreach my $idx (@indices) {
    next unless (defined($form->{$idx}));

    if (!ref($form->{$idx})) {
      $form->{$idx} = $form->format_amount(\%myconfig, $form->{$idx}, $places);

    } elsif (ref($form->{$idx}) eq "ARRAY") {
      for (my $i = 0; $i < scalar(@{$form->{$idx}}); $i++) {
        $form->{$idx}->[$i] =
          $form->format_amount(\%myconfig, $form->{$idx}->[$i], $places);
      }
    }
  }

  $myconfig{"numberformat"} = $saved_numberformat;

  $lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub show_history {
	$lxdebug->enter_sub();
	my $dbh = $form->dbconnect(\%myconfig);
	my ($sort, $sortby) = split(/\-\-/, $form->{order});
  $sort =~ s/.*\.(.*)/$1/;

	$form->{title} = $locale->text("History");
    $form->header();
    print $form->parse_html_template( "common/show_history", {
    	"DATEN" => $form->get_history($dbh,$form->{input_name},"",$form->{order}),
    	"SUCCESS" => ($form->get_history($dbh,$form->{input_name}) ne "0"),
      uc($sort) => 1,
      uc($sort)."BY" => $sortby
    	} );

	$dbh->disconnect();
	$lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub call_sub {
  $lxdebug->enter_sub();

  my $name = shift;

  if (!$name) {
    $form->error($locale->text("Trying to call a sub without a name"));
  }

  $name =~ s/[^a-zA-Z0-9_]//g;

  if (!defined(&{ $name })) {
    $form->error(sprintf($locale->text("Attempt to call an undefined sub named '%s'"), $name));
  }

  &{ $name }(@_);

  $lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub show_vc_details {
	$lxdebug->enter_sub();

  $form->{vc} = $form->{vc} eq "customer" ? "customer" : "vendor";
  $form->isblank("vc_id",
                 $form->{vc} eq "customer" ?
                 $locale->text("No customer has been selected yet.") :
                 $locale->text("No vendor has been selected yet."));

  Common->get_vc_details(\%myconfig, $form, $form->{vc}, $form->{vc_id});

  $form->{title} = $form->{vc} eq "customer" ?
    $locale->text("Customer details") : $locale->text("Vendor details");
  $form->header();
  print $form->parse_html_template("common/show_vc_details", { "is_customer" => $form->{vc} eq "customer" });

	$lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub retrieve_partunits {
  $lxdebug->enter_sub();

  my @part_ids = grep { $_ } map { $form->{"id_${_}"} } (1..$form->{rowcount});

  if (@part_ids) {
    my %partunits = IO->retrieve_partunits('part_ids' => \@part_ids);

    foreach my $i (1..$form->{rowcount}) {
      next unless ($form->{"id_${i}"});
      $form->{"partunit_${i}"} = $partunits{$form->{"id_${i}"}};
    }
  }

  $lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub mark_as_paid_common {
  $lxdebug->enter_sub();

  my ($myconfig, $db_name) = @_;

  if($form->{mark_as_paid}) {
    my $dbh ||= $form->get_standard_dbh($myconfig);
    my $query = qq|UPDATE $db_name SET paid = amount WHERE id = ?|;
    do_query($form, $dbh, $query, $form->{id});
    $dbh->commit();
    $form->redirect($locale->text("Marked as paid"));

  } else {
    my $referer = $ENV{HTTP_REFERER};
    $referer =~ s/^(.*)action\=.*\&(.*)$/$1action\=mark_as_paid\&mark_as_paid\=1\&id\=$form->{id}\&$2/;
    $form->header();
    print qq|<body>|;
    print qq|<p><b>|.$locale->text('Mark as paid?').qq|</b></p>|;
    print qq|<input type="button" value="|.$locale->text('yes').qq|" onclick="document.location.href='|.$referer.qq|'">&nbsp;|;
    print qq|<input type="button" value="|.$locale->text('no').qq|" onclick="javascript:history.back();">|;
    print qq|</body></html>|;
  }

  $lxdebug->leave_sub();
}

sub cov_selection_internal {
  $lxdebug->enter_sub();

  $order_by = "name";
  $order_by = $form->{"order_by"} if (defined($form->{"order_by"}));
  $order_dir = 1;
  $order_dir = $form->{"order_dir"} if (defined($form->{"order_dir"}));

  my $type = $form->{"is_vendor"} ? $locale->text("vendor") : $locale->text("customer");

  $covs = Common->retrieve_customers_or_vendors(\%myconfig, $form, $order_by, $order_dir, $form->{"is_vendor"}, $form->{"allow_both"});
  map({ $covs->[$_]->{"selected"} = $_ ? 0 : 1; } (0..$#{$covs}));
  if (0 == scalar(@{$covs})) {
    $form->show_generic_information(sprintf($locale->text("No %s was found matching the search parameters."), $type));
  } elsif (1 == scalar(@{$covs})) {
    $onload = "cov_selected('1')";
  }

  my $callback = "$form->{script}?action=cov_selection_internal&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login path password name input_name input_id is_vendor allow_both), grep({ /^[fl]_/ } keys %$form)));

  my @header_sort = qw(name address contact);
  my %header_title = ( "name" => $locale->text("Name"),
                       "address" => $locale->text("Address"),
                       "contact" => $locale->text("Contact"),
                       );

  my @header =
    map(+{ "column_title" => $header_title{$_},
           "column" => $_,
           "callback" => $callback . "order_by=${_}&order_dir=" . ($order_by eq $_ ? 1 - $order_dir : $order_dir),
         },
        @header_sort);

  foreach my $cov (@{ $covs }) {
    $cov->{address} = "$cov->{street}, $cov->{zipcode} $cov->{city}";
    $cov->{address} =~ s{^,}{}x;
    $cov->{address} =~ s{\ +}{\ }gx;

    $cov->{contact} = join " ", map { $cov->{$_} } qw(cp_greeting cp_title cp_givenname cp_name);
    $cov->{contact} =~ s{\ +}{\ }gx;
  }

  $form->{"title"} = $form->{is_vendor} ? $locale->text("Select a vendor") : $locale->text("Select a customer");
  $form->header();
  print($form->parse_html_template("generic/cov_selection", { "HEADER" => \@header,
                                                              "COVS" => $covs,
                                                              "onload" => $onload }));

  $lxdebug->leave_sub();
}

sub check_cov2 {
  $lxdebug->enter_sub();

  my $callback_sub = shift;

  if (!$form->{customer}
      || ($form->{customer} eq $form->{old_customer})
      || ("$form->{customer}--$form->{customer_id}" eq $form->{old_customer})) {
    $lxdebug->leave_sub();
    return;
  }

  $old_name     = $form->{name};
  $form->{name} = $form->{customer};

  my $covs = Common->retrieve_customers_or_vendors(\%myconfig, $form, "name", "ASC", 0, 1);

  $form->{name} = $old_name;

  if (0 == scalar @{$covs}) {
    $form->show_generic_information(sprintf($locale->text("No %s was found matching the search parameters."), $type));

  } elsif (1 == scalar @{ $covs }) {
    $form->{customer}           = $covs->[0]->{name};
    $form->{old_customer}       = $covs->[0]->{name};
    $form->{customer_id}        = $covs->[0]->{id};
    $form->{customer_is_vendor} = $covs->[0]->{customer_is_vendor};

  } else {
    $form->{new_cov_nextsub} = $callback_sub;

    delete @{$form}{qw(customer customer_is_vendor customer_id old_customer action)};
    my @hidden = map { { 'key' => $_, 'value' => $form->{$_} } } grep { '' eq ref $form->{$_} } keys %{ $form };

    foreach my $cov (@{ $covs }) {
      $cov->{address} = "$cov->{street}, $cov->{zipcode} $cov->{city}";
      $cov->{address} =~ s{^,}{}x;
      $cov->{address} =~ s{\ +}{\ }gx;

      $cov->{contact} = join " ", map { $cov->{$_} } qw(cp_greeting cp_title cp_givenname cp_name);
      $cov->{contact} =~ s{\ +}{\ }gx;
    }

    $form->{title} = $locale->text("Select a vendor or customer");
    $form->header();

    print $form->parse_html_template("generic/cov_selection2", { "COVS" => $covs, "HIDDEN" => \@hidden });

    exit 0;
  }

  $lxdebug->leave_sub();
}

sub cov_selected2 {
  $lxdebug->enter_sub();

  if (!$form->{new_cov} || !$form->{new_cov_nextsub}) {
    $form->error($locale->text('No customer has been selected.'));
  }

  map { $form->{$_} = $form->{"new_cov_${_}_$form->{new_cov}"} } qw(customer customer_id customer_is_vendor);
  $form->{old_customer} = $form->{customer};

  &{ $form->{new_cov_nextsub} }();

  $lxdebug->leave_sub();
}

sub select_item_selection_internal {
  $lxdebug->enter_sub();

  @items = SystemBrace->retrieve_select_items(\%myconfig, $form, $form->{"select_item_type"});
  if (0 == scalar(@items)) {
    $form->show_generic_information($locale->text("No item was found."));
  } elsif (1 == scalar(@items)) {
    $onload = "select_item_selected('1')";
  }

  $form->{"title"} = $locale->text("Select an entry");
  $form->header();
  print($form->parse_html_template("generic/select_item_selection", { "SELECT_ITEMS" => \@items,
                                                                      "onload" => $onload }));

  $lxdebug->leave_sub();
}
1;
