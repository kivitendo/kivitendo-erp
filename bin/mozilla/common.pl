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
use SL::DB::Helper::Mappings;
use SL::DB;
use SL::DBUtils qw(do_query);
use SL::Form;
use SL::MoreCommon qw(restore_form save_form);

use strict;

sub build_std_url {
  $main::lxdebug->enter_sub(2);

  my $form     = $main::form;

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

  $main::lxdebug->leave_sub(2);

  return $url;
}

# -------------------------------------------------------------------------

sub delivery_customer_selection {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $order_by = "name";
  $order_by = $form->{"order_by"} if (defined($form->{"order_by"}));
  my $order_dir = 1;
  $order_dir = $form->{"order_dir"} if (defined($form->{"order_dir"}));

  my $delivery = Common->retrieve_delivery_customer(\%myconfig, $form, $order_by, $order_dir);
  map({ $delivery->[$_]->{"selected"} = $_ ? 0 : 1; } (0..$#{$delivery}));

  if (0 == scalar(@{$delivery})) {
    $form->show_generic_information($locale->text("No Customer was found matching the search parameters."));
  } elsif (1 == scalar(@{$delivery})) {
    $::request->{layout}->add_javascripts_inline("customer_selected('1')");
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
  $form->header(no_layout => 1);
  print $form->parse_html_template("generic/select_delivery_customer", { "HEADER"   => \@header,
                                                                         "DELIVERY" => $delivery, });

  $main::lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub vendor_selection {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $order_by = "name";
  $order_by = $form->{"order_by"} if (defined($form->{"order_by"}));
  my $order_dir = 1;
  $order_dir = $form->{"order_dir"} if (defined($form->{"order_dir"}));

  my $vendor = Common->retrieve_vendor(\%myconfig, $form, $order_by, $order_dir);
  map({ $vendor->[$_]->{"selected"} = $_ ? 0 : 1; } (0..$#{$vendor}));

  if (0 == scalar(@{$vendor})) {
    $form->show_generic_information($locale->text("No Vendor was found matching the search parameters."));
  } elsif (1 == scalar(@{$vendor})) {
    $::request->{layout}->add_javascripts_inline("vendor_selected('1')");
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
  $form->header(no_layout => 1);
  print $form->parse_html_template("generic/select_vendor", { "HEADER" => \@header,
                                                              "VENDOR" => $vendor, });

  $main::lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub calculate_qty {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->{formel} =~ s/\r\n//g;

  my ($variable_string, $formel) = split /###/,$form->{formel};
  my @variable;

  foreach my $item (split m/;/, $variable_string) {
    next unless $item =~ m/^ \s* (\w+) \s* = \s* (\w+) \s* (\w+) \s* $/x;
    push @variable, {
      description => $1,
      name        => $2,
      unit        => $3,
    };
  }

  my @header_sort = qw(variable value unit);
  my %header_title = (
    variable => $locale->text("Variable"),
    value    => $locale->text("Value"),
    unit     => $locale->text("Unit"),
  );
  my @header = map +{
    column_title => $header_title{$_},
    column       => $_,
  }, @header_sort;

  $form->{formel} = $formel;
  my $html = $form->parse_html_template("generic/calculate_qty", { "HEADER"    => \@header,
                                                                   "VARIABLES" => \@variable, });
  print $::form->ajax_response_header, $html;

  $main::lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub H {
  return $main::locale->quote_special_chars('HTML', $_[0]);
}

sub Q {
  return $main::locale->quote_special_chars('URL@HTML', $_[0]);
}

sub E {
  return $main::form->escape($_[0]);
}

sub NTI {
  my ($element) = @_;

  $element =~ s/tabindex\s*=\s*"\d+"//;
  return $element;
}

sub format_dates {
  return $::form->format_dates(@_);
}

sub reformat_numbers {
  return $::form->reformat_numbers(@_);
}

# -------------------------------------------------------------------------

sub show_history {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $dbh = $form->dbconnect(\%myconfig);
  my ($sort, $sortby) = split(/\-\-/, $form->{order});
  $sort =~ s/.*\.(.*)/$1/;

  $form->{title} = $locale->text("History");
  $form->header(no_layout => 1);

  my $callback = build_std_url(qw(action longdescription trans_id_type input_name));
  my $restriction;
  if ( $form->{trans_id_type} eq 'glid' ) {
    $restriction = "AND ( snumbers LIKE 'invnumber%' OR what_done LIKE '%Buchungsnummer%' OR snumbers LIKE 'gltransaction%' OR snumbers LIKE 'emailjournal%' ) ";
  } elsif ( $form->{trans_id_type} eq 'id' ) {
    $restriction = " AND ( snumbers NOT LIKE 'invnumber_%' AND snumbers NOT LIKE 'gltransaction%' AND snumbers NOT LIKE 'emailjournal%' AND (what_done NOT LIKE '%Buchungsnummer%' OR what_done IS null))";
  } else {
    $restriction = '';
  };

  print $form->parse_html_template( "common/show_history", {
    "DATEN"        => $form->get_history($dbh,$form->{input_name},$restriction,$form->{order}),
    "SUCCESS"      => ($form->get_history($dbh,$form->{input_name}) ne "0"),
    uc($sort)      => 1,
    uc($sort)."BY" => $sortby,
    callback       => $callback,
  } );

  $dbh->disconnect();
  $main::lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub call_sub {
  $main::lxdebug->enter_sub();

  my $name = shift;

  my $form     = $main::form;
  my $locale   = $main::locale;

  if (!$name) {
    $form->error($locale->text("Trying to call a sub without a name"));
  }

  $name =~ s/[^a-zA-Z0-9_]//g;

  if (!defined(&{ $name })) {
    $form->error(sprintf($locale->text("Attempt to call an undefined sub named '%s'"), $name));
  }

  {
    no strict "refs";
    &{ $name }(@_);
  }

  $main::lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub show_vc_details {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{vc} = $form->{vc} eq "customer" ? "customer" : "vendor";
  $form->isblank("vc_id",
                 $form->{vc} eq "customer" ?
                 $locale->text("No customer has been selected yet.") :
                 $locale->text("No vendor has been selected yet."));

  Common->get_vc_details(\%myconfig, $form, $form->{vc}, $form->{vc_id});
  $form->{discount_as_percent} = $form->format_amount(\%::myconfig, $form->parse_amount(\%::myconfig, $form->{discount}) * 100, 2);

  $form->{title} = $form->{vc} eq "customer" ?
    $locale->text("Customer details") : $locale->text("Vendor details");
  $form->header(no_layout => 1);
  print $form->parse_html_template("common/show_vc_details", { "is_customer" => $form->{vc} eq "customer" });

  $main::lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub retrieve_partunits {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  my @part_ids = grep { $_ } map { $form->{"id_${_}"} } (1..$form->{rowcount});

  if (@part_ids) {
    my %partunits = IO->retrieve_partunits('part_ids' => \@part_ids);

    foreach my $i (1..$form->{rowcount}) {
      next unless ($form->{"id_${i}"});
      $form->{"partunit_${i}"} = $partunits{$form->{"id_${i}"}};
    }
  }

  $main::lxdebug->leave_sub();
}

# -------------------------------------------------------------------------

sub cov_selection_internal {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $order_by = "name";
  $order_by = $form->{"order_by"} if (defined($form->{"order_by"}));
  my $order_dir = 1;
  $order_dir = $form->{"order_dir"} if (defined($form->{"order_dir"}));

  my $type = $form->{"is_vendor"} ? $locale->text("vendor") : $locale->text("customer");

  my $covs = Common->retrieve_customers_or_vendors(\%myconfig, $form, $order_by, $order_dir, $form->{"is_vendor"}, $form->{"allow_both"});
  map({ $covs->[$_]->{"selected"} = $_ ? 0 : 1; } (0..$#{$covs}));

  if (0 == scalar(@{$covs})) {
    $form->show_generic_information(sprintf($locale->text("No %s was found matching the search parameters."), $type));
  } elsif (1 == scalar(@{$covs})) {
    $::request->{layout}->add_javascripts_inline("cov_selected('1')");
  }

  my $callback = "$form->{script}?action=cov_selection_internal&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(name input_name input_id is_vendor allow_both), grep({ /^[fl]_/ } keys %$form)));

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

    $cov->{contact} = join " ", map { $cov->{$_} } qw(cp_gender cp_title cp_givenname cp_name);
    $cov->{contact} =~ s{\ +}{\ }gx;
  }

  $form->{"title"} = $form->{is_vendor} ? $locale->text("Select a vendor") : $locale->text("Select a customer");
  $form->header();
  print($form->parse_html_template("generic/cov_selection", { "HEADER" => \@header,
                                                              "COVS" => $covs, }));

  $main::lxdebug->leave_sub();
}


# Functions to call add routines beneath different reports

sub sales_invoice {
  $main::lxdebug->enter_sub();

  print $::form->redirect_header('is.pl?action=add&type=invoice');

  $main::lxdebug->leave_sub();
}

sub ar_transaction {
  $main::lxdebug->enter_sub();

  print $::form->redirect_header('ar.pl?action=add');

  $main::lxdebug->leave_sub();
}

sub vendor_invoice {
  $main::lxdebug->enter_sub();

  print $::form->redirect_header('ir.pl?action=add&type=invoice');

  $main::lxdebug->leave_sub();
}

sub ap_transaction {
  $main::lxdebug->enter_sub();

  print $::form->redirect_header('ap.pl?action=add');

  $main::lxdebug->leave_sub();
}

sub gl_transaction {
  $main::lxdebug->enter_sub();

  print $::form->redirect_header('gl.pl?action=add');

  $main::lxdebug->leave_sub();
}

sub db {
  goto &SL::DB::Helper::Mappings::db;
}

sub continue { call_sub($::form->{nextsub}); }

1;
