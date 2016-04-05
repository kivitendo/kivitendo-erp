#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Inventory invoicing module
#
#======================================================================

use SL::FU;
use SL::IS;
use SL::PE;
use SL::OE;
use Data::Dumper;
use DateTime;
use List::MoreUtils qw(uniq);
use List::Util qw(max sum);
use List::UtilsBy qw(sort_by);
use English qw(-no_match_vars);

use SL::DB::Default;
use SL::DB::Customer;
use SL::DB::PaymentTerm;

require "bin/mozilla/io.pl";
require "bin/mozilla/arap.pl";
require "bin/mozilla/drafts.pl";

use strict;

1;

# end of main

sub add {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');

  return $main::lxdebug->leave_sub() if (load_draft_maybe());

  $form->{show_details} = $::myconfig{show_form_details};

  if ($form->{type} eq "credit_note") {
    $form->{title} = $locale->text('Add Credit Note');

    if ($form->{storno}) {
      $form->{title} = $locale->text('Add Storno Credit Note');
    }
  } else {
    $form->{title} = $locale->text('Add Sales Invoice');

  }


  $form->{callback} = "$form->{script}?action=add&type=$form->{type}" unless $form->{callback};

  &invoice_links;
  &prepare_invoice;
  &display_form;

  $main::lxdebug->leave_sub();
}

sub edit {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');

  $form->{show_details}                = $::myconfig{show_form_details};
  $form->{taxincluded_changed_by_user} = 1;

  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;

  my ($language_id, $printer_id);
  if ($form->{print_and_post}) {
    $form->{action}   = "print";
    $form->{resubmit} = 1;
    $language_id = $form->{language_id};
    $printer_id = $form->{printer_id};
  }

  &invoice_links;
  if ($form->{type} eq "credit_note") {
    $form->{title} = $locale->text('Edit Credit Note');
    $form->{title} = $locale->text('Edit Storno Credit Note') if $form->{storno};
  } else {
    $form->{title} = $locale->text('Edit Sales Invoice');
    $form->{title} = $locale->text('Edit Storno Invoice')     if $form->{storno};
  }

  &prepare_invoice;
  if ($form->{print_and_post}) {
    $form->{language_id} = $language_id;
    $form->{printer_id} = $printer_id;
  }

  &display_form;

  $main::lxdebug->leave_sub();
}

sub invoice_links {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('invoice_edit');

  $form->{vc} = 'customer';

  # create links
  $form->create_links("AR", \%myconfig, "customer");

  if ($form->{all_customer}) {
    unless ($form->{customer_id}) {
      $form->{customer_id} = $form->{all_customer}->[0]->{id};
      $form->{salesman_id} = $form->{all_customer}->[0]->{salesman_id};
    }
  }

  my $editing = $form->{id};

  $form->backup_vars(qw(payment_id language_id taxzone_id salesman_id
                        taxincluded currency cp_id intnotes id shipto_id
                        delivery_term_id));

  IS->get_customer(\%myconfig, \%$form);

  #quote all_customer Bug 133
  foreach my $ref (@{ $form->{all_customer} }) {
    $ref->{name} = $form->quote($ref->{name});
  }

  $form->restore_vars(qw(id));

  IS->retrieve_invoice(\%myconfig, \%$form);
  $form->restore_vars(qw(payment_id language_id taxzone_id currency intnotes
                         cp_id shipto_id delivery_term_id));
  $form->restore_vars(qw(taxincluded)) if $form->{id};
  $form->restore_vars(qw(salesman_id)) if $editing;


  # build vendor/customer drop down compatibility... don't ask
  if (@{ $form->{"all_customer"} }) {
    $form->{"selectcustomer"} = 1;
    $form->{customer}         = qq|$form->{customer}--$form->{"customer_id"}|;
  }

  $form->{"oldcustomer"}  = $form->{customer};

  if ($form->{"oldcustomer"} !~ m/--\d+$/ && $form->{"customer_id"}) {
    $form->{"oldcustomer"} .= qq|--$form->{"customer_id"}|
  }


#  $form->{oldcustomer} = "$form->{customer}--$form->{customer_id}";
#  $form->{selectcustomer} = 1;

  $form->{employee} = "$form->{employee}--$form->{employee_id}";

  # forex
  $form->{forex} = $form->{exchangerate};
  my $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  foreach my $key (keys %{ $form->{AR_links} }) {
    foreach my $ref (@{ $form->{AR_links}{$key} }) {
      $form->{"select$key"} .= "<option>$ref->{accno}--$ref->{description}</option>\n";
    }

    if ($key eq "AR_paid") {
      next unless $form->{acc_trans}{$key};
      for my $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {
        $form->{"AR_paid_$i"}      = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";

        $form->{"acc_trans_id_$i"}    = $form->{acc_trans}{$key}->[$i - 1]->{acc_trans_id};
        # reverse paid
        $form->{"paid_$i"}         = $form->{acc_trans}{$key}->[$i - 1]->{amount} * -1;
        $form->{"datepaid_$i"}     = $form->{acc_trans}{$key}->[$i - 1]->{transdate};
        $form->{"gldate_$i"}       = $form->{acc_trans}{$key}->[$i - 1]->{gldate};
        $form->{"exchangerate_$i"} = $form->{acc_trans}{$key}->[$i - 1]->{exchangerate};
        $form->{"forex_$i"}        = $form->{"exchangerate_$i"};
        $form->{"source_$i"}       = $form->{acc_trans}{$key}->[$i - 1]->{source};
        $form->{"memo_$i"}         = $form->{acc_trans}{$key}->[$i - 1]->{memo};

        $form->{paidaccounts} = $i;
      }
    } else {
      $form->{$key} = "$form->{acc_trans}{$key}->[0]->{accno}--$form->{acc_trans}{$key}->[0]->{description}";
    }
  }

  $form->{paidaccounts} = 1 unless (exists $form->{paidaccounts});

  $form->{AR} = $form->{AR_1} unless $form->{id};

  $form->{locked} = ($form->datetonum($form->{invdate},  \%myconfig)
                  <= $form->datetonum($form->{closedto}, \%myconfig));

  $main::lxdebug->leave_sub();
}

sub prepare_invoice {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('invoice_edit');

  if ($form->{type} eq "credit_note") {
    $form->{type}     = "credit_note";
    $form->{formname} = "credit_note";
  } else {
    $form->{type}     = "invoice";
    $form->{formname} = "invoice";
  }

  if ($form->{id}) {

    my $i = 0;

    foreach my $ref (@{ $form->{invoice_details} }) {
      $i++;

      map { $form->{"${_}_$i"} = $ref->{$_} } keys %{$ref};

      $form->{"discount_$i"}   = $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100);
      my ($dec)                = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec                     = length $dec;
      my $decimalplaces        = ($dec > 2) ? $dec : 2;

      $form->{"sellprice_$i"}  = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
      (my $dec_qty)            = ($form->{"qty_$i"} =~ /\.(\d+)/);
      $dec_qty                 = length $dec_qty;

      $form->{"lastcost_$i"}  = $form->format_amount(\%myconfig, $form->{"lastcost_$i"}, $decimalplaces);

      $form->{"qty_$i"}        = $form->format_amount(\%myconfig, $form->{"qty_$i"}, $dec_qty);

      $form->{"sellprice_pg_$i"} = join ('--', $form->{"sellprice_$i"}, $form->{"pricegroup_id_$i"});

      $form->{rowcount}        = $i;

    }
  }
  $main::lxdebug->leave_sub();
}

sub form_header {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  $main::auth->assert('invoice_edit');

  my %TMPL_VAR = ();
  my @custom_hiddens;

  if ($form->{id}) {
    require SL::DB::Invoice;
    $TMPL_VAR{invoice_obj} = SL::DB::Invoice->new(id => $form->{id})->load;
  }
  $form->{employee_id} = $form->{old_employee_id} if $form->{old_employee_id};
  $form->{salesman_id} = $form->{old_salesman_id} if $form->{old_salesman_id};

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  $form->get_lists("taxzones"      => ($form->{id} ? "ALL_TAXZONES" : "ALL_ACTIVE_TAXZONES"),
                   "currencies"    => "ALL_CURRENCIES",
                   "customers"     => "ALL_CUSTOMERS",
                   "departments"   => "all_departments",
                   "price_factors" => "ALL_PRICE_FACTORS");

  # Projects
  my @old_project_ids = uniq grep { $_ } map { $_ * 1 } ($form->{"globalproject_id"}, map { $form->{"project_id_$_"} } 1..$form->{"rowcount"});
  my @old_ids_cond    = @old_project_ids ? (id => \@old_project_ids) : ();
  my @customer_cond;
  if ($::instance_conf->get_customer_projects_only_in_sales) {
    @customer_cond = (
      or => [
        customer_id          => $::form->{customer_id},
        billable_customer_id => $::form->{customer_id},
      ]);
  }
  my @conditions = (
    or => [
      and => [ active => 1, @customer_cond ],
      @old_ids_cond,
    ]);

  $TMPL_VAR{ALL_PROJECTS}          = SL::DB::Manager::Project->get_all_sorted(query => \@conditions);
  $form->{ALL_PROJECTS}            = $TMPL_VAR{ALL_PROJECTS}; # make projects available for second row drop-down in io.pl
  $TMPL_VAR{ALL_EMPLOYEES}         = SL::DB::Manager::Employee->get_all_sorted(query => [ or => [ id => $::form->{employee_id},  deleted => 0 ] ]);
  $TMPL_VAR{ALL_SALESMEN}          = SL::DB::Manager::Employee->get_all_sorted(query => [ or => [ id => $::form->{salesman_id},  deleted => 0 ] ]);
  $TMPL_VAR{ALL_SHIPTO}            = SL::DB::Manager::Shipto->get_all_sorted(query => [
    or => [ trans_id  => $::form->{"$::form->{vc}_id"} * 1, and => [ shipto_id => $::form->{shipto_id} * 1, trans_id => undef ] ]
  ]);
  $TMPL_VAR{ALL_CONTACTS}          = SL::DB::Manager::Contact->get_all_sorted(query => [
    or => [
      cp_cv_id => $::form->{"$::form->{vc}_id"} * 1,
      and      => [
        cp_cv_id => undef,
        cp_id    => $::form->{cp_id} * 1
      ]
    ]
  ]);
  $TMPL_VAR{department_labels}     = sub { "$_[0]->{description}--$_[0]->{id}" };

  # customer
  $TMPL_VAR{vc_keys} = sub { "$_[0]->{name}--$_[0]->{id}" };
  $TMPL_VAR{vclimit} = $myconfig{vclimit};
  $TMPL_VAR{vc_select} = "customer_or_vendor_selection_window('customer', '', 0, 0)";
  push @custom_hiddens, "customer_id";
  push @custom_hiddens, "oldcustomer";
  push @custom_hiddens, "selectcustomer";

  # currencies and exchangerate
  my @values = map { $_       } @{ $form->{ALL_CURRENCIES} };
  my %labels = map { $_ => $_ } @{ $form->{ALL_CURRENCIES} };
  $form->{currency}            = $form->{defaultcurrency} unless $form->{currency};
  $form->{show_exchangerate}   = $form->{currency} ne $form->{defaultcurrency};
  $TMPL_VAR{currencies}        = NTI($::request->{cgi}->popup_menu('-name' => 'currency', '-default' => $form->{"currency"},
                                                      '-values' => \@values, '-labels' => \%labels,
                                                      '-onchange' => "document.getElementById('update_button').click();"
                                     )) if scalar @values;
  push @custom_hiddens, "forex";
  push @custom_hiddens, "exchangerate" if $form->{forex};

  $TMPL_VAR{creditwarning} = ($form->{creditlimit} != 0) && ($form->{creditremaining} < 0) && !$form->{update};
  $TMPL_VAR{is_credit_remaining_negativ} = $form->{creditremaining} =~ /-/;

  my $follow_up_vc         =  $form->{customer};
  $follow_up_vc            =~ s/--\d*\s*$//;
  $TMPL_VAR{customer_name} = $follow_up_vc;

# set option selected
  foreach my $item (qw(AR)) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  $TMPL_VAR{is_type_credit_note} = $form->{type}   eq "credit_note";
  $TMPL_VAR{is_format_html}      = $form->{format} eq 'html';
  $TMPL_VAR{dateformat}          = $myconfig{dateformat};
  $TMPL_VAR{numberformat}        = $myconfig{numberformat};

  push @custom_hiddens, map { "shiptocvar_" . $_->name } @{ SL::DB::Manager::CustomVariableConfig->get_all(where => [ module => 'ShipTo' ]) };

  # hiddens
  $TMPL_VAR{HIDDENS} = [qw(
    id action type media format queued printed emailed title vc discount
    title creditlimit creditremaining tradediscount business closedto locked shipped storno storno_id
    max_dunning_level dunning_amount dunning_description
    shiptoname shiptostreet shiptozipcode shiptocity shiptocountry shiptogln shiptocontact shiptophone shiptofax
    shiptoemail shiptodepartment_1 shiptodepartment_2  shiptocp_gender message email subject cc bcc taxaccounts cursor_fokus
    convert_from_do_ids convert_from_oe_ids convert_from_ar_ids useasnew
    invoice_id
    show_details
  ), @custom_hiddens,
  map { $_.'_rate', $_.'_description', $_.'_taxnumber' } split / /, $form->{taxaccounts}];

  $::request->{layout}->use_javascript(map { "${_}.js" } qw(kivi.SalesPurchase ckeditor/ckeditor ckeditor/adapters/jquery kivi.io autocomplete_customer autocomplete_part client_js));

  $TMPL_VAR{payment_terms_obj} = get_payment_terms_for_invoice();
  $form->{duedate}             = $TMPL_VAR{payment_terms_obj}->calc_date(reference_date => $form->{invdate}, due_date => $form->{duedate})->to_kivitendo if $TMPL_VAR{payment_terms_obj};

  $form->header();

  print $form->parse_html_template("is/form_header", \%TMPL_VAR);

  $main::lxdebug->leave_sub();
}

sub _sort_payments {
  my @fields   = qw(acc_trans_id gldate datepaid source memo paid AR_paid);
  my @payments =
    grep { $_->{paid} != 0 }
    map  {
      my $idx = $_;
      +{ map { ($_ => delete($::form->{"${_}_${idx}"})) } @fields }
    } (1..$::form->{paidaccounts});

  @payments = sort_by { DateTime->from_kivitendo($_->{datepaid}) } @payments;

  $::form->{paidaccounts} = max scalar(@payments), 1;

  foreach my $idx (1 .. scalar(@payments)) {
    my $payment = $payments[$idx - 1];
    $::form->{"${_}_${idx}"} = $payment->{$_} for @fields;
  }
}

sub form_footer {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');

  $form->{invtotal}    = $form->{invsubtotal};

  # note rows
  $form->{rows} = max 2,
    $form->numtextrows($form->{notes},    26, 8),
    $form->numtextrows($form->{intnotes}, 35, 8);


  # tax, total and subtotal calculations
  my ($tax, $subtotal);
  $form->{taxaccounts_array} = [ split(/ /, $form->{taxaccounts}) ];

  if( $form->{customer_id} && !$form->{taxincluded_changed_by_user} ) {
    my $customer = SL::DB::Customer->new(id => $form->{customer_id})->load();
    $form->{taxincluded} = defined($customer->taxincluded_checked) ? $customer->taxincluded_checked : $myconfig{taxincluded_checked};
  }

  foreach my $item (@{ $form->{taxaccounts_array} }) {
    if ($form->{"${item}_base"}) {
      if ($form->{taxincluded}) {
        $form->{"${item}_total"} = $form->round_amount( ($form->{"${item}_base"} * $form->{"${item}_rate"}
                                                                                 / (1 + $form->{"${item}_rate"})), 2);
        $form->{"${item}_netto"} = $form->round_amount( ($form->{"${item}_base"} - $form->{"${item}_total"}), 2);
      } else {
        $form->{"${item}_total"} = $form->round_amount( $form->{"${item}_base"} * $form->{"${item}_rate"}, 2);
        $form->{invtotal} += $form->{"${item}_total"};
      }
    }
  }

  $form->{rounding} = $form->round_amount(
    $form->round_amount($form->{invtotal}, 2, 1) - $form->round_amount($form->{invtotal}, 2), 2
  );
  $form->{invtotal} = $form->round_amount( $form->{invtotal}, 2, 1 );

  # follow ups
  if ($form->{id}) {
    $form->{follow_ups}            = FU->follow_ups('trans_id' => $form->{id}) || [];
    $form->{follow_ups_unfinished} = ( sum map { $_->{due} * 1 } @{ $form->{follow_ups} } ) || 0;
  }

  # payments
  _sort_payments();

  my $totalpaid = 0;
  $form->{paidaccounts}++ if ($form->{"paid_$form->{paidaccounts}"});
  $form->{paid_indices} = [ 1 .. $form->{paidaccounts} ];

  # Standard Konto für Umlaufvermögen
  my $accno_arap = IS->get_standard_accno_current_assets(\%myconfig, \%$form);

  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"changeable_$i"} = 1;
    if (SL::DB::Default->get->payments_changeable == 0) {
      # never
      $form->{"changeable_$i"} = ($form->{"acc_trans_id_$i"})? 0 : 1;
    } elsif (SL::DB::Default->get->payments_changeable == 2) {
      # on the same day
      $form->{"changeable_$i"} = (($form->{"gldate_$i"} eq '') ||
                                  ($form->current_date(\%myconfig) eq $form->{"gldate_$i"}));
    }

    $form->{"selectAR_paid_$i"} = $form->{selectAR_paid};
    if (!$form->{"AR_paid_$i"}) {
      $form->{"selectAR_paid_$i"} =~ s/option>$accno_arap--(.*?)</option selected>$accno_arap--$1</;
    } else {
      $form->{"selectAR_paid_$i"} =~ s/option>\Q$form->{"AR_paid_$i"}\E/option selected>$form->{"AR_paid_$i"}/;
    }

    $totalpaid += $form->{"paid_$i"};
  }

  $form->{oldinvtotal} = $form->{invtotal};

  $form->{ALL_DELIVERY_TERMS} = SL::DB::Manager::DeliveryTerm->get_all_sorted();

  print $form->parse_html_template('is/form_footer', {
    is_type_credit_note => ($form->{type} eq "credit_note"),
    totalpaid           => $totalpaid,
    paid_missing        => $form->{invtotal} - $totalpaid,
    print_options       => print_options(inline => 1),
    show_storno         => $form->{id} && !$form->{storno} && !IS->has_storno(\%myconfig, $form, "ar") && !$totalpaid,
    show_delete         => ($::instance_conf->get_is_changeable == 2)
                             ? ($form->current_date(\%myconfig) eq $form->{gldate})
                             : ($::instance_conf->get_is_changeable == 1),
    today               => DateTime->today,
  });
##print $form->parse_html_template('is/_payments'); # parser
##print $form->parse_html_template('webdav/_list'); # parser

  $main::lxdebug->leave_sub();
}

sub mark_as_paid {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('invoice_edit');

  &mark_as_paid_common(\%myconfig,"ar");

  $main::lxdebug->leave_sub();
}

sub update {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('invoice_edit');

  my ($recursive_call) = @_;

  $form->{print_and_post} = 0         if $form->{second_run};
  my $taxincluded         = $form->{taxincluded} ? "checked" : '';
  $form->{update} = 1;

  &check_name("customer");

  $form->{taxincluded} ||= $taxincluded;

  if (!$form->{forex}) {        # read exchangerate from input field (not hidden)
    $form->{exchangerate} = $form->parse_amount(\%myconfig, $form->{exchangerate}) unless $recursive_call;
  }
  $form->{forex}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{invdate}, 'buy');
  $form->{exchangerate} = $form->{forex} if $form->{forex};

  for my $i (1 .. $form->{paidaccounts}) {
    next unless $form->{"paid_$i"};
    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);
    if (!$form->{"forex_$i"}) {   #read exchangerate from input field (not hidden)
      $form->{exchangerate} = $form->{"exchangerate_$i"};
    }
    $form->{"forex_$i"}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy');
    $form->{"exchangerate_$i"} = $form->{"forex_$i"} if $form->{"forex_$i"};
  }

  my $i            = $form->{rowcount};
  my $exchangerate = $form->{exchangerate} || 1;

  # if last row empty, check the form otherwise retrieve new item
  if (   ($form->{"partnumber_$i"} eq "")
      && ($form->{"description_$i"} eq "")
      && ($form->{"partsgroup_$i"}  eq "")) {

    $form->{creditremaining} += ($form->{oldinvtotal} - $form->{oldtotalpaid});
    &check_form;

  } else {

    IS->retrieve_item(\%myconfig, \%$form);

    my $rows = scalar @{ $form->{item_list} };

    $form->{"discount_$i"}   = $form->parse_amount(\%myconfig, $form->{"discount_$i"}) / 100.0;
    $form->{"discount_$i"} ||= $form->{customer_discount};

    if ($rows) {
      $form->{"qty_$i"} = $form->parse_amount(\%myconfig, $form->{"qty_$i"});
      if( !$form->{"qty_$i"} ) {
        $form->{"qty_$i"} = 1;
      }

      if ($rows > 1) {

        select_item(mode => 'IS', pre_entered_qty => $form->{"qty_$i"});
        ::end_of_request();

      } else {

        my $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});

        map { $form->{item_list}[$i]{$_} =~ s/\"/&quot;/g } qw(partnumber description unit);
        map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} } keys %{ $form->{item_list}[0] };

        $form->{payment_id}    = $form->{"part_payment_id_$i"} if $form->{"part_payment_id_$i"} ne "";
        $form->{"discount_$i"} = 0                             if $form->{"not_discountable_$i"};

        $form->{"marge_price_factor_$i"} = $form->{item_list}->[0]->{price_factor};

        ($sellprice || $form->{"sellprice_$i"}) =~ /\.(\d+)/;
        my $decimalplaces = max 2, length $1;

        if ($sellprice) {
          $form->{"sellprice_$i"} = $sellprice;
        } else {
          my $record        = _make_record();
          my $price_source  = SL::PriceSource->new(record_item => $record->items->[$i-1], record => $record);
          my $best_price    = $price_source->best_price;
          my $best_discount = $price_source->best_discount;

          if ($best_price) {
            $::form->{"sellprice_$i"}           = $best_price->price;
            $::form->{"active_price_source_$i"} = $best_price->source;
          }
          if ($best_discount) {
            $::form->{"discount_$i"}               = $best_discount->discount;
            $::form->{"active_discount_source_$i"} = $best_discount->source;
          }

          # if there is an exchange rate adjust sellprice
          $form->{"sellprice_$i"} /= $exchangerate;
        }

        $form->{"listprice_$i"} /= $exchangerate;

        my $amount = $form->{"sellprice_$i"} * $form->{"qty_$i"} * (1 - $form->{"discount_$i"});
        map { $form->{"${_}_base"} = 0 }                                 split / /, $form->{taxaccounts};
        map { $form->{"${_}_base"} += $amount }                          split / /, $form->{"taxaccounts_$i"};
        map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{"taxaccounts_$i"} if !$form->{taxincluded};

        $form->{creditremaining} -= $amount;

        map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, $decimalplaces) } qw(sellprice lastcost);

        $form->{"qty_$i"}      = $form->format_amount(\%myconfig, $form->{"qty_$i"});
        $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100.0);
      }

      &display_form;

    } else {

      # ok, so this is a new part
      # ask if it is a part or service item

      if (   $form->{"partsgroup_$i"}
          && ($form->{"partsnumber_$i"} eq "")
          && ($form->{"description_$i"} eq "")) {
        $form->{rowcount}--;
        $form->{"discount_$i"} = "";
        display_form();

      } else {
        $form->{"id_$i"}   = 0;
        new_item();
      }
    }
  }
  $main::lxdebug->leave_sub();
}

sub post_payment {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');

  $form->mtime_ischanged('ar') ;
  my $invdate = $form->datetonum($form->{invdate}, \%myconfig);

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      my $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));


      if ($form->{currency} ne $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($invdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }
    }
  }
  # Abgeschlossene Zeiträume nur für den letzten (aktuellen) Zahlungseingang prüfen
  # Details s.a. Bug 1502
  # Das Problem ist jetzt, dass man Zahlungseingänge nachträglich ändern kann
  # Wobei dies für Installationen die sowieso nicht mit Bücherkontrolle arbeiten keinen
  # keinen Unterschied macht.
  # Optimal wäre, wenn gegen einen Zeitstempel des Zahlungsfelds geprüft würde ...
  # Das Problem hierbei ist, dass in IS.pm post_invoice IMMER alle Zahlungseingänge aus $form
  # erneut gespeichert werden. Prinzipiell wäre es besser NUR die Änderungen des Rechnungs-
  # belegs (neue Zahlung aber nichts anderes) zu speichern ...
  # Vielleicht könnte man ähnlich wie bei Rechnung löschen verfahren
  $form->error($locale->text('Cannot post payment for a closed period!'))
    if ($form->date_closed($form->{"datepaid_$form->{paidaccounts}"}, \%myconfig));

  ($form->{AR})      = split /--/, $form->{AR};
  ($form->{AR_paid}) = split /--/, $form->{AR_paid};
  relink_accounts();
  if ( IS->post_payment(\%myconfig, \%$form) ) {
    $form->{snumbers}  = qq|invnumber_| . $form->{invnumber};
    $form->{what_done} = 'invoice';
    $form->{addition}  = "PAYMENT POSTED";
    $form->save_history;
    $form->redirect($locale->text('Payment posted!'))
  } else {
   $form->error($locale->text('Cannot post payment!'));
  };

  $main::lxdebug->leave_sub();
}

sub post {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');
  $form->mtime_ischanged('ar');

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);
  $form->isblank("invdate",  $locale->text('Invoice Date missing!'));
  $form->isblank("customer", $locale->text('Customer missing!'));
  $form->error($locale->text('Cannot post invoice for a closed period!'))
        if ($form->date_closed($form->{"invdate"}, \%myconfig));

  $form->{invnumber} =~ s/^\s*//g;
  $form->{invnumber} =~ s/\s*$//g;

  # if oldcustomer ne customer redo form
  if (&check_name('customer')) {
    &update;
    ::end_of_request();
  }

  if ($myconfig{mandatory_departments} && !$form->{department_id}) {
    $form->{saved_message} = $::locale->text('You have to specify a department.');
    update();
    exit;
  }

  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
  }

  remove_emptied_rows();
  &validate_items;

  my $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  my $invdate  = $form->datetonum($form->{invdate},  \%myconfig);

  $form->error($locale->text('Cannot post transaction above the maximum future booking date!'))
    if ($form->date_max_future($invdate, \%myconfig));
  $form->error($locale->text('Cannot post invoice for a closed period!'))
    if ($invdate <= $closedto);

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      my $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($form->date_closed($form->{"datepaid_$i"}, \%myconfig));

      if ($form->{currency} ne $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($invdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  ($form->{AR})        = split /--/, $form->{AR};
  ($form->{AR_paid})   = split /--/, $form->{AR_paid};
  $form->{storno}    ||= 0;

  $form->{label} = $form->{type} eq 'credit_note' ? $locale->text('Credit Note') : $locale->text('Invoice');

  $form->{id} = 0 if $form->{postasnew};

  # get new invnumber in sequence if no invnumber is given or if posasnew was requested
  if ($form->{postasnew}) {
    if ($form->{type} eq "credit_note") {
      undef($form->{cnnumber});
    } else {
      undef($form->{invnumber});
    }
  }

  relink_accounts();

  my $terms        = get_payment_terms_for_invoice();
  $form->{duedate} = $terms->calc_date(reference_date => $form->{invdate}, due_date => $form->{due_due})->to_kivitendo if $terms;

  # If transfer_out is requested, get rose db handle and do post and
  # transfer out in one transaction. Otherwise just post the invoice.
  if ($::instance_conf->get_is_transfer_out && $form->{type} ne 'credit_note' && !$form->{storno}) {
    require SL::DB::Inventory;
    my $rose_db = SL::DB::Inventory->new->db;
    my @errors;

    if (!$rose_db->with_transaction(sub {
      if (!eval {
        if (!IS->post_invoice(\%myconfig, \%$form, $rose_db->dbh)) {
          push @errors, $locale->text('Cannot post invoice!');
          die 'posting error';
        }
        my $err = IS->transfer_out(\%$form, $rose_db->dbh);
        if (@{ $err }) {
          push @errors, @{ $err };
          die 'transfer error';
        }

        1;
      }) {
        push @errors, $EVAL_ERROR;
        die 'transaction error';
      }

      1;
    })) {
      push @errors, $rose_db->error;
      $form->error($locale->text('Cannot post invoice and/or transfer out! Error message:') . "\n" . join("\n", @errors));
    }
  } else {
    if (!IS->post_invoice(\%myconfig, \%$form)) {
      $form->error($locale->text('Cannot post invoice!'));
    }
  }

  remove_draft() if $form->{remove_draft};

  if(!exists $form->{addition}) {
    $form->{snumbers}  =  'invnumber' .'_'. $form->{invnumber}; # ($form->{type} eq 'credit_note' ? 'cnnumber' : 'invnumber') .'_'. $form->{invnumber};
    $form->{what_done} = 'invoice';
    $form->{addition}  = $form->{print_and_post} ? "PRINTED AND POSTED" :
                         $form->{storno}         ? "STORNO"             :
                                                   "POSTED";
    $form->save_history;
  }

  if (!$form->{no_redirect_after_post}) {
    $form->{action} = 'edit';
    $form->{script} = 'is.pl';
    $form->{saved_message} = $form->{label} . " $form->{invnumber} " . $locale->text('posted!');
    $form->{callback} = build_std_url(qw(action edit id callback saved_message));
    $form->redirect;
  }

  $main::lxdebug->leave_sub();
}

sub print_and_post {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('invoice_edit');

  my $old_form                    = Form->new;
  $form->{no_redirect_after_post} = 1;
  $form->{print_and_post}         = 1;
  &post();

  &edit();
  $main::lxdebug->leave_sub();

}

sub use_as_new {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('invoice_edit');

  delete @{ $form }{qw(printed emailed queued invnumber invdate exchangerate forex deliverydate id datepaid_1 gldate_1 acc_trans_id_1 source_1 memo_1 paid_1 exchangerate_1 AP_paid_1 storno locked)};
  $form->{rowcount}--;
  $form->{paidaccounts} = 1;
  $form->{invdate}      = $form->current_date(\%myconfig);
  my $terms             = get_payment_terms_for_invoice();
  $form->{duedate}      = $terms ? $terms->calc_date(reference_date => $form->{invdate})->to_kivitendo : $form->{invdate};
  $form->{employee_id}  = SL::DB::Manager::Employee->current->id;
  $form->{forex}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{invdate}, 'buy');
  $form->{exchangerate} = $form->{forex} if $form->{forex};

  $form->{"converted_from_invoice_id_$_"} = delete $form->{"invoice_id_$_"} for 1 .. $form->{"rowcount"};

  $form->{useasnew} = 1;
  &display_form;

  $main::lxdebug->leave_sub();
}

sub storno {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');

  if ($form->{storno}) {
    $form->error($locale->text('Cannot storno storno invoice!'));
  }

  if (IS->has_storno(\%myconfig, $form, "ar")) {
    $form->error($locale->text("Invoice has already been storno'd!"));
  }
  if ($form->datetonum($form->{invdate},  \%myconfig) <= $form->datetonum($form->{closedto}, \%myconfig)) {
    $form->error($locale->text('Cannot storno invoice for a closed period!'));
  }

  # save the history of invoice being stornoed
  $form->{snumbers}  = qq|invnumber_| . $form->{invnumber};
  $form->{what_done} = 'invoice';
  $form->{addition}  = "STORNO";
  $form->save_history;

  map({ my $key = $_; delete($form->{$key}) unless (grep({ $key eq $_ } qw(id login password type))); } keys(%{ $form }));

  invoice_links();
  prepare_invoice();
  relink_accounts();

  # Payments must not be recorded for the new storno invoice.
  $form->{paidaccounts} = 0;
  map { my $key = $_; delete $form->{$key} if grep { $key =~ /^$_/ } qw(datepaid_ gldate_ acc_trans_id_ source_ memo_ paid_ exchangerate_ AR_paid_) } keys %{ $form };

  $form->{storno_id} = $form->{id};
  $form->{storno} = 1;
  $form->{id} = "";
  $form->{invnumber} = "Storno zu " . $form->{invnumber};
  $form->{invdate}   = DateTime->today->to_lxoffice;
  $form->{rowcount}++;
  # set new ids for storno invoice
  delete $form->{"invoice_id_$_"} for 1 .. $form->{"rowcount"};

  post();
  $main::lxdebug->leave_sub();
}

sub preview {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('invoice_edit');

  $form->{preview} = 1;
  my $old_form = Form->new;
  for (keys %$form) { $old_form->{$_} = $form->{$_} }

  &print_form($old_form);
  $main::lxdebug->leave_sub();

}

sub delete {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');

  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
  }
  $form->header;

  print qq|
<form method="post" action="$form->{script}">
|;

  # delete action variable
  map { delete $form->{$_} } qw(action header);

  foreach my $key (keys %$form) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type="hidden" name="$key" value="$form->{$key}">\n|;
  }

  print qq|
<h2 class="confirm">| . $locale->text('Confirm!') . qq|</h2>

<h4>|
    . $locale->text('Are you sure you want to delete Invoice Number')
    . qq| $form->{invnumber}
</h4>

<p>
<input name="action" class="submit" type="submit" value="|
    . $locale->text('Yes') . qq|">
</form>
|;

  $main::lxdebug->leave_sub();
}

sub credit_note {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');

  $form->{transdate} = $form->{invdate} = $form->current_date(\%myconfig);
  $form->{duedate} =
    $form->current_date(\%myconfig, $form->{invdate}, $form->{terms} * 1);

  $form->{convert_from_ar_ids} = $form->{id};
  $form->{id}     = '';
  $form->{rowcount}--;


  $form->{title}  = $locale->text('Add Credit Note');
  $form->{script} = 'is.pl';

  # Bei Gutschriften bezug zur Rechnungsnummer
  $form->{invnumber_for_credit_note} = $form->{invnumber};
  # bo creates the id, reset it
  map { delete $form->{$_} }
    qw(id invnumber subject message cc bcc printed emailed queued);
  $form->{ $form->{vc} } =~ s/--.*//g;
  $form->{type} = "credit_note";


  map { $form->{"select$_"} = "" } ($form->{vc}, 'currency');

#  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
#    qw(creditlimit creditremaining);

  # set new persistent ids for credit note and link previous invoice id
  $form->{"converted_from_invoice_id_$_"} = delete $form->{"invoice_id_$_"} for 1 .. $form->{"rowcount"};

  my $currency = $form->{currency};
  &invoice_links;

  $form->{currency}     = $currency;
  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{invdate}, 'buy');
  $form->{exchangerate} = $form->{forex} || '';

  $form->{creditremaining} -= ($form->{oldinvtotal} - $form->{ordtotal});

  # bei Gutschriften werden Zahlungseingänge aus Rechnung nicht übernommen
  for my $i (1 .. $form->{paidaccounts}) {
    delete $form->{"paid_$i"};
    delete $form->{"source_$i"};
    delete $form->{"memo_$i"};
    delete $form->{"datepaid_$i"};
    delete $form->{"gldate_$i"};
    delete $form->{"acc_trans_id_$i"};
    delete $form->{"AR_paid_$i"};
  };
  $form->{paidaccounts} = 1;

  &prepare_invoice;


  &display_form;

  $main::lxdebug->leave_sub();
}

sub display_form {
  $::lxdebug->enter_sub;

  $::auth->assert('invoice_edit');

  relink_accounts();

  my $new_rowcount = $::form->{"rowcount"} * 1 + 1;
  $::form->{"project_id_${new_rowcount}"} = $::form->{"globalproject_id"};

  $::form->language_payment(\%::myconfig);

  Common::webdav_folder($::form);

  form_header();
  display_row(++$::form->{rowcount});
  form_footer();

  $::lxdebug->leave_sub;
}

sub yes {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');

  if (IS->delete_invoice(\%myconfig, \%$form)) {
    # saving the history
    if(!exists $form->{addition}) {
      $form->{snumbers}  = 'invnumber' .'_'. $form->{invnumber}; # ($form->{type} eq 'credit_note' ? 'cnnumber' : 'invnumber') .'_'. $form->{invnumber};
      $form->{what_done} = 'invoice';
      $form->{addition}  = "DELETED";
      $form->save_history;
    }
    # /saving the history
    $form->redirect($locale->text('Invoice deleted!'));
  }
  $form->error($locale->text('Cannot delete invoice!'));

  $main::lxdebug->leave_sub();
}

sub post_and_e_mail {
  e_mail();
};

sub e_mail {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('invoice_edit');

  if (!$form->{id}) {
    $form->{no_redirect_after_post} = 1;

    my $saved_form = save_form();

    post();

    restore_form($saved_form, 0, qw(id invnumber));
  }

  edit_e_mail();

  $main::lxdebug->leave_sub();
}
