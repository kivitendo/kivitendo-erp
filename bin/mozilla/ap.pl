#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2001
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
#
# Accounts Payables
#
#======================================================================

use POSIX qw(strftime);
use List::Util qw(first max sum);
use List::UtilsBy qw(sort_by);

use SL::AP;
use SL::FU;
use SL::GL;
use SL::Helper::Flash qw(flash flash_later);
use SL::IR;
use SL::IS;
use SL::ReportGenerator;
use SL::DB::BankTransactionAccTrans;
use SL::DB::Chart;
use SL::DB::Currency;
use SL::DB::Default;
use SL::DB::InvoiceItem;
use SL::DB::Order;
use SL::DB::PaymentTerm;
use SL::DB::PurchaseInvoice;
use SL::DB::RecordTemplate;
use SL::DB::Tax;
use SL::DB::EmailJournal;
use SL::DB::ValidityToken;
use SL::Presenter::ItemsList;
use SL::Webdav;
use SL::ZUGFeRD;
use SL::Locale::String qw(t8);

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

use strict;

1;

# end of main

# this is for our long dates
# $locale->text('January')
# $locale->text('February')
# $locale->text('March')
# $locale->text('April')
# $locale->text('May ')
# $locale->text('June')
# $locale->text('July')
# $locale->text('August')
# $locale->text('September')
# $locale->text('October')
# $locale->text('November')
# $locale->text('December')

# this is for our short month
# $locale->text('Jan')
# $locale->text('Feb')
# $locale->text('Mar')
# $locale->text('Apr')
# $locale->text('May')
# $locale->text('Jun')
# $locale->text('Jul')
# $locale->text('Aug')
# $locale->text('Sep')
# $locale->text('Oct')
# $locale->text('Nov')
# $locale->text('Dec')

sub _may_view_or_edit_this_invoice {
  return 1 if  $::auth->assert('ap_transactions', 1); # may edit all invoices
  return 0 if !$::form->{id};                         # creating new invoices isn't allowed without invoice_edit
  return 0 if !$::form->{globalproject_id};           # existing records without a project ID are not allowed
  return SL::DB::Project->new(id => $::form->{globalproject_id})->load->may_employee_view_project_invoices(SL::DB::Manager::Employee->current);
}

sub _assert_access {
  my $cache = $::request->cache('ap.pl::_assert_access');

  $cache->{_may_view_or_edit_this_invoice} = _may_view_or_edit_this_invoice()                              if !exists $cache->{_may_view_or_edit_this_invoice};
  $::form->show_generic_error($::locale->text("You do not have the permissions to access this function.")) if !       $cache->{_may_view_or_edit_this_invoice};
}

sub load_zugferd {
  $::auth->assert('ap_transactions');

  my $file_name = $::form->{form_defaults}->{zugferd_session_file};
  if ($file_name) {
    flash('info', $::locale->text(
        "The ZUGFeRD/Factur-X invoice '#1' has been loaded.", $file_name));
  }

  my $template_ap;
  $template_ap ||= SL::DB::RecordTemplate->new(id => $::form->{record_template_id})->load()
    if $::form->{record_template_id};
  $template_ap ||= SL::DB::Manager::RecordTemplate->get_first(where => [vendor_id => $::form->{form_defaults}->{vendor_id}])
    if $::form->{form_defaults}->{vendor_id};
  if ($template_ap) {
    $::form->{id} = $template_ap->id;
    # set default values for items
    my $template_item = $template_ap->items->[0];
    my $chart = SL::DB::Chart->new(id => $template_item->chart_id)->load();
    my $tax = SL::DB::Tax->new(id => $template_item->tax_id)->load();
    foreach my $pos (1 .. $::form->{form_defaults}->{rowcount}) {
      $::form->{form_defaults}->{"AP_amount_chart_id_$pos"}          = $chart->id;
      $::form->{form_defaults}->{"previous_AP_amount_chart_id_$pos"} = $chart->id;
      $::form->{form_defaults}->{"taxchart_$pos"}   = $tax->id . '--' . $tax->rate;
      $::form->{form_defaults}->{"project_id_$pos"} = $template_item->project_id;

    }
    $::form->{form_defaults}->{FLASH} = $::form->{FLASH}; # store flash, form gets cleared
    return load_record_template();
  } else {
    flash('warning', $::locale->text(
        "No AP Record Template for vendor '#1' found.", $::form->{form_defaults}->{vendor}));
  }

  my $form_defaults = delete $::form->{form_defaults};
  $::form->{$_} = $form_defaults->{$_} for keys %{ $form_defaults // {} };
  $::form->{title} ||= "Add";
  $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST())->token;
  update(
    keep_rows_without_amount => 1,
    dont_add_new_row         => 1,
  );
}

sub load_record_template {
  $::auth->assert('ap_transactions');

  # Load existing template and verify that its one for this module.
  my $template = SL::DB::RecordTemplate
    ->new(id => $::form->{id})
    ->load(
      with_object => [ qw(customer payment currency record_items record_items.chart) ],
    );

  die "invalid template type" unless $template->template_type eq 'ap_transaction';

  $template->substitute_variables;

  # Clean the current $::form before rebuilding it from the template.
  my $form_defaults = delete $::form->{form_defaults};
  delete @{ $::form }{ grep { !m{^(?:script|login)$}i } keys %{ $::form } };

  # Fill $::form from the template.
  my $today                   = DateTime->today_local;
  $::form->{title}            = "Add";
  $::form->{currency}         = $template->currency->name;
  $::form->{direct_debit}     = $template->direct_debit;
  $::form->{globalproject_id} = $template->project_id;
  $::form->{payment_id}       = $template->payment_id;
  $::form->{AP_chart_id}      = $template->ar_ap_chart_id;
  $::form->{transdate}        = $today->to_kivitendo;
  $::form->{duedate}          = $today->to_kivitendo;
  $::form->{rowcount}         = @{ $template->items };
  $::form->{paidaccounts}     = 1;
  $::form->{$_}               = $template->$_ for qw(department_id ordnumber taxincluded notes transaction_description);

  if ($template->vendor) {
    $::form->{vendor_id} = $template->vendor_id;
    $::form->{vendor}    = $template->vendor->name;
    $::form->{duedate}   = $template->vendor->payment->calc_date(reference_date => $today)->to_kivitendo if $template->vendor->payment;
  }

  my $row = 0;
  foreach my $item (@{ $template->items }) {
    $row++;

    my $active_taxkey = $item->chart->get_active_taxkey;
    my $taxes         = SL::DB::Manager::Tax->get_all(
      where   => [ chart_categories => { like => '%' . $item->chart->category . '%' }],
      sort_by => 'taxkey, rate',
    );

    my $tax   = first { $item->tax_id          == $_->id } @{ $taxes };
    $tax    //= first { $active_taxkey->tax_id == $_->id } @{ $taxes };
    $tax    //= $taxes->[0];

    if (!$tax) {
      $row--;
      next;
    }

    $::form->{"AP_amount_chart_id_${row}"}          = $item->chart_id;
    $::form->{"previous_AP_amount_chart_id_${row}"} = $item->chart_id;
    $::form->{"amount_${row}"}                      = $::form->format_amount(\%::myconfig, $item->amount1, 2);
    $::form->{"taxchart_${row}"}                    = $item->tax_id . '--' . $tax->rate;
    $::form->{"project_id_${row}"}                  = $item->project_id;
  }

  $::form->{$_} = $form_defaults->{$_} for keys %{ $form_defaults // {} };

  flash('info', $::locale->text("The record template '#1' has been loaded.", $template->template_name));
  flash('info', $::locale->text("Payment bookings disallowed. After the booking this record may be " .
                                "suggested with the amount of '#1' or otherwise has to be choosen manually." .
                                " No automatic payment booking will be done to chart '#2'.",
                                  $form_defaults->{paid_1_suggestion},
                                  $form_defaults->{AP_paid_1_suggestion},
                                )) if $::form->{no_payment_bookings};

  $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST())->token;

  update(
    keep_rows_without_amount => 1,
    dont_add_new_row         => 1,
  );
}

sub save_record_template {
  $::auth->assert('ap_transactions');

  my $template = $::form->{record_template_id} ? SL::DB::RecordTemplate->new(id => $::form->{record_template_id})->load : SL::DB::RecordTemplate->new;
  my $js       = SL::ClientJS->new(controller => SL::Controller::Base->new);
  my $new_name = $template->template_name_to_use($::form->{record_template_new_template_name});

  $js->dialog->close('#record_template_dialog');

  my @items = grep {
    $_->{chart_id} && (($_->{tax_id} // '') ne '')
  } map {
    +{ chart_id   => $::form->{"AP_amount_chart_id_${_}"},
       amount1    => $::form->parse_amount(\%::myconfig, $::form->{"amount_${_}"}),
       tax_id     => (split m{--}, $::form->{"taxchart_${_}"})[0],
       project_id => $::form->{"project_id_${_}"} || undef,
     }
  } (1..($::form->{rowcount} || 1));

  $template->assign_attributes(
    template_type           => 'ap_transaction',
    template_name           => $new_name,

    currency_id             => SL::DB::Manager::Currency->find_by(name => $::form->{currency})->id,
    ar_ap_chart_id          => $::form->{AP_chart_id}      || undef,
    vendor_id               => $::form->{vendor_id}        || undef,
    department_id           => $::form->{department_id}    || undef,
    project_id              => $::form->{globalproject_id} || undef,
    payment_id              => $::form->{payment_id}       || undef,
    taxincluded             => $::form->{taxincluded}  ? 1 : 0,
    direct_debit            => $::form->{direct_debit} ? 1 : 0,
    ordnumber               => $::form->{ordnumber},
    notes                   => $::form->{notes},
    transaction_description => $::form->{transaction_description},

    items                   => \@items,
  );

  eval {
    $template->save;
    1;
  } or do {
    return $js
      ->flash('error', $::locale->text("Saving the record template '#1' failed.", $new_name))
      ->render;
  };

  return $js
    ->flash('info', $::locale->text("The record template '#1' has been saved.", $new_name))
    ->render;
}

sub add {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('ap_transactions');

  $form->{title} = "Add";

  $form->{callback} = "ap.pl?action=add" unless $form->{callback};

  AP->get_transdate(\%myconfig, $form);
  $form->{initial_transdate} = $form->{transdate};
  $form->{initial_vendor_id} = $form->{vendor_id};
  create_links(dont_save => 1);
  $form->{transdate} = $form->{initial_transdate};
  $form->{vendor_id} = $form->{initial_vendor_id} if $form->{initial_vendor_id};

  if ($form->{vendor_id}) {
    my $vendor = SL::DB::Vendor->load_cached($form->{vendor_id});

    # set initial payment terms
    $form->{payment_id} = $vendor->payment_id;

    my $last_used_ap_chart = $vendor->last_used_ap_chart;
    $form->{"AP_amount_chart_id_1"} = $last_used_ap_chart->id if $last_used_ap_chart;
  }

  if (!$form->{form_validity_token}) {
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST())->token;
  }

  &display_form;

  $main::lxdebug->leave_sub();
}

sub edit {
  $main::lxdebug->enter_sub();

  # Delay access check to after the invoice's been loaded in
  # "create_links" so that project-specific invoice rights can be
  # evaluated.

  my $form     = $main::form;

  $form->{title} = "Edit";

  create_links();
  &display_form;

  $main::lxdebug->leave_sub();
}

sub display_form {
  $main::lxdebug->enter_sub();

  _assert_access();

  my $form     = $main::form;

  # get all files stored in the webdav folder
  if ($form->{invnumber} && $::instance_conf->get_webdav) {
    my $webdav = SL::Webdav->new(
      type     => 'accounts_payable',
      number   => $form->{invnumber},
    );
    my @all_objects = $webdav->get_all_objects;
    @{ $form->{WEBDAV} } = map { { name => $_->filename,
                                   type => t8('File'),
                                   link => File::Spec->catfile($_->full_filedescriptor),
                               } } @all_objects;
  }
  &form_header;
  &form_footer;

  $main::lxdebug->leave_sub();
}

sub create_links {
  $main::lxdebug->enter_sub();

  # Delay access check to after the invoice's been loaded so that
  # project-specific invoice rights can be evaluated.

  my %params   = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->create_links("AP", \%myconfig, "vendor");

  _assert_access();

  my %saved;
  if (!$params{dont_save}) {
    %saved = map { ($_ => $form->{$_}) } qw(direct_debit taxincluded);
    $saved{duedate} = $form->{duedate} if $form->{duedate};
    $saved{currency} = $form->{currency} if $form->{currency};
    $saved{taxincluded} = $form->{taxincluded} if $form->{taxincluded};
    $saved{intnotes} = $form->{intnotes} if $form->{intnotes};
  }

  IR->get_vendor(\%myconfig, \%$form);

  $form->{$_}        = $saved{$_} for keys %saved;
  $form->{rowcount}  = 1;
  $form->{AP_chart_id} = $form->{acc_trans} && $form->{acc_trans}->{AP} ? $form->{acc_trans}->{AP}->[0]->{chart_id} : $::instance_conf->get_ap_chart_id || $form->{AP_links}->{AP}->[0]->{chart_id};

  # build the popup menus
  $form->{taxincluded} = ($form->{id}) ? $form->{taxincluded} : "checked";

  $::form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;

  $form->{employee} = "$form->{employee}--$form->{employee_id}";

  AP->setup_form($form);

  $main::lxdebug->leave_sub();
}

sub _sort_payments {
  my @fields   = qw(acc_trans_id gldate datepaid source memo paid AP_paid paid_project_id);
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

sub form_header {
  $main::lxdebug->enter_sub();

  _assert_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  $::form->{invoice_obj} = SL::DB::PurchaseInvoice->new(id => $::form->{id})->load if $::form->{id};

  $form->{initial_focus} = !($form->{amount_1} * 1) ? 'vendor_id' : 'row_' . $form->{rowcount};

  $form->{title_} = $form->{title};
  $form->{title} = $form->{title} eq 'Add' ? $locale->text('Add Accounts Payables Transaction') : $locale->text('Edit Accounts Payables Transaction');

  # type=submit $locale->text('Add Accounts Payables Transaction')
  # type=submit $locale->text('Edit Accounts Payables Transaction')

  # currencies
  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);
  if ($form->{currency} ne $form->{defaultcurrency} && !$form->{exchangerate}) {
    my $transdate    = $form->{transdate}  ? DateTime->from_kivitendo($form->{transdate}) : DateTime->today_local;
    ($form->{exchangerate}, $form->{record_forex}) = $form->{id}
                                                  ?  $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{transdate}, "sell", $form->{id}, 'ap')
                                                  :  $form->check_exchangerate(\%myconfig, $form->{currency}, $transdate, "sell");
  }

  # format amounts
  $form->{creditlimit}     = $form->format_amount(\%myconfig, $form->{creditlimit}, 0, "0");
  $form->{creditremaining} = $form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0");

  my $rows;
  if (($rows = $form->numtextrows($form->{notes}, 50)) < 2) {
    $rows = 2;
  }
  $form->{textarea_rows} = $rows;

  $form->{creditremaining_plus} = ($form->{creditremaining} =~ /-/) ? "0" : "1";

  $form->get_lists("charts"    => { "key"       => "ALL_CHARTS",
                                    "transdate" => $form->{transdate} },
                  );

  map(
    { $_->{link_split} = [ split(/:/, $_->{link}) ]; }
    @{ $form->{ALL_CHARTS} }
  );

  $form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;

  my %project_labels = map { $_->id => $_->projectnumber }  @{ SL::DB::Manager::Project->get_all };

  my (%charts, %bank_accounts);
  my $default_ap_amount_chart_id;
  # don't add manual bookings for charts which are assigned to real bank accounts
  # and are flagged for use with bank import
  my $bank_accounts = SL::DB::Manager::BankAccount->get_all();
  foreach my $bank (@{ $bank_accounts }) {
    if ($bank->use_with_bank_import) {
      my $accno_paid_bank = $bank->chart->accno;
      $bank_accounts{$accno_paid_bank} = 1;
    }
  }

  foreach my $item (@{ $form->{ALL_CHARTS} }) {
    if ( grep({ $_ eq 'AP_amount' } @{ $item->{link_split} }) ) {
      $default_ap_amount_chart_id //= $item->{id};

    } elsif ( grep({ $_ eq 'AP_paid' } @{ $item->{link_split} }) ) {
      next if $bank_accounts{$item->{accno}};
      push(@{ $form->{ALL_CHARTS_AP_paid} }, $item);
    }

    $charts{$item->{accno}} = $item;
  }

  my $follow_up_vc         = $form->{vendor_id} ? SL::DB::Vendor->load_cached($form->{vendor_id})->name : '';
  my $follow_up_trans_info =  "$form->{invnumber} ($follow_up_vc)";

  $::request->layout->add_javascripts("autocomplete_chart.js", "show_history.js", "follow_up.js", "kivi.Draft.js", "kivi.SalesPurchase.js", "kivi.GL.js", "kivi.RecordTemplate.js", "kivi.File.js", "kivi.AP.js", "kivi.CustomerVendor.js", "kivi.Validator.js", "autocomplete_project.js");
  # $form->{totalpaid} is used by the action bar setup to determine
  # whether or not canceling is allowed. Therefore it must be
  # calculated prior to the action bar setup.
  $form->{totalpaid} = sum map { $form->{"paid_${_}"} } (1..$form->{paidaccounts});

  setup_ap_display_form_action_bar();

  $form->header();
  # get the correct date for tax
  my $transdate    = $::form->{transdate}    ? DateTime->from_kivitendo($::form->{transdate})    : DateTime->today_local;
  my $deliverydate = $::form->{deliverydate} ? DateTime->from_kivitendo($::form->{deliverydate}) : undef;
  my $taxdate      = $deliverydate ? $deliverydate : $transdate;
  # helper for loop
  my $first_taxchart;

  for my $i (1 .. $form->{rowcount}) {

    # format amounts
    $form->{"amount_$i"} = $form->format_amount(\%myconfig, $form->{"amount_$i"}, 2);
    $form->{"tax_$i"} = $form->format_amount(\%myconfig, $form->{"tax_$i"}, 2);

    my ($default_taxchart, $taxchart_to_use);
    my $used_tax_id;
    if ( $form->{"taxchart_$i"} ) {
      ($used_tax_id) = split(/--/, $form->{"taxchart_$i"});
    }
    my $amount_chart_id = $form->{"AP_amount_chart_id_$i"} || $default_ap_amount_chart_id;

    my @taxcharts       = GL->get_active_taxes_for_chart($amount_chart_id, $taxdate, $used_tax_id);
    foreach my $item (@taxcharts) {
      my $key             = $item->id . "--" . $item->rate;
      $first_taxchart   //= $item;
      $default_taxchart   = $item if $item->{is_default};
      $taxchart_to_use    = $item if $key eq $form->{"taxchart_$i"};
    }

    $taxchart_to_use               //= $default_taxchart // $first_taxchart;
    my $selected_taxchart            = $taxchart_to_use->id . '--' . $taxchart_to_use->rate;
    $form->{"selected_taxchart_$i"}  = $selected_taxchart;
    $form->{"AP_amount_chart_id_$i"} = $amount_chart_id;
    $form->{"taxcharts_$i"}          = \@taxcharts;

    # reverse charge hack for template, display two taxes
    if ($taxchart_to_use->reverse_charge_chart_id) {
      my $tmpnetamount;
      ($tmpnetamount, $form->{"tax_reverse_$i"}) = $form->calculate_tax($form->parse_amount(\%myconfig, $form->{"amount_$i"}),
                                                                        $taxchart_to_use->rate, $form->{taxincluded}, 2        );

      $form->{"tax_charge_$i"}  = $form->{"tax_reverse_$i"} * -1;
      $form->{"tax_reverse_$i"} = $form->format_amount(\%myconfig, $form->{"tax_reverse_$i"}, 2);
      $form->{"tax_charge_$i"}  = $form->format_amount(\%myconfig, $form->{"tax_charge_$i"}, 2);
    }
  }

  $form->{taxchart_value_title_sub} = sub {
    my $item = shift;
    return [
      $item->{id} .'--'. $item->{rate},
      $item->{taxkey} . ' - ' . $item->{taxdescription} .' '. ($item->{rate} * 100) .' %',
    ];
  };

  $form->{AP_paid_value_title_sub} = sub {
    my $item = shift;
    return [
      $item->{accno},
      $item->{accno} .'--'. $item->{description}
    ];
  };

  $form->{invtotal_unformatted} = $form->{invtotal};
  $form->{invtotal} = $form->format_amount(\%myconfig, $form->{invtotal}, 2);

  _sort_payments();

  if ( $form->{'paid_'. $form->{paidaccounts}} ) {
    $form->{paidaccounts}++;
  }

  # default account for current assets (i.e. 1801 - SKR04)
  $form->{accno_arap} = IS->get_standard_accno_current_assets(\%myconfig, \%$form);

  # reset form value of defaultcurrency_totalpaid, as it is currently a hidden and otherwise it gets accumulated after each update
  # is only used if there are exchange rates
  $form->{"defaultcurrency_totalpaid"} = 0;

  for my $i (1 .. $form->{paidaccounts}) {
    # hook for calc of of defaultcurrency_paid and check if banktransaction has a record exchangerate
    if ($form->{"exchangerate_$i"} && $form->{"acc_trans_id_$i"}) {
      my $bt_acc_trans = SL::DB::Manager::BankTransactionAccTrans->find_by(acc_trans_id => $form->{"acc_trans_id_$i"});
      if ($bt_acc_trans) {
        if ($bt_acc_trans->bank_transaction->exchangerate > 0) {
          $form->{"exchangerate_$i"} = $bt_acc_trans->bank_transaction->exchangerate;
          $form->{"forex_$i"}        = $form->{"exchangerate_$i"};
          $form->{"record_forex_$i"} = 1;
        }
      }
      if (!$form->{"fx_transaction_$i"}) {
        # this is a banktransaction that was paid in internal currency. revert paid/defaultcurrency_paid
        $form->{"defaultcurrency_paid_$i"} = $form->{"paid_$i"};
        $form->{"paid_$i"} /= $form->{"exchangerate_$i"};
      }
      $form->{"defaultcurrency_paid_$i"} //= $form->{"paid_$i"} * $form->{"exchangerate_$i"};
      $form->{"defaultcurrency_totalpaid"} +=  $form->{"defaultcurrency_paid_$i"};
    } # end hook defaultcurrency_paid
    # format amounts
    if ($form->{"paid_$i"}) {
      $form->{"paid_$i"} = $form->format_amount(\%myconfig, $form->{"paid_$i"}, 2);
    }
    if ($form->{"exchangerate_$i"} == 0) {
      $form->{"exchangerate_$i"} = "";
    } else {
      $form->{"exchangerate_$i"} =
        $form->format_amount(\%myconfig, $form->{"exchangerate_$i"});
    }

    my $changeable = 1;
    if (SL::DB::Default->get->payments_changeable == 0) {
      # never
      $changeable = ($form->{"acc_trans_id_$i"})? 0 : 1;
    }
    if (SL::DB::Default->get->payments_changeable == 2) {
      # on the same day
      $changeable = (($form->{"gldate_$i"} eq '') || $form->current_date(\%myconfig) eq $form->{"gldate_$i"});
    }

    #deaktivieren von gebuchten Zahlungen ausserhalb der Bücherkontrolle, vorher prüfen ob heute eingegeben
    if ($form->date_closed($form->{"gldate_$i"})) {
       $changeable = 0;
    }

    $form->{'paidaccount_changeable_'. $i} = $changeable;

    $form->{'labelpaid_project_id_'. $i} = $project_labels{$form->{'paid_project_id_'. $i}};
    # accno and description as info text
    $form->{'AP_paid_readonly_desc_' . $i} =  $form->{'AP_paid_' . $i} ?
       $form->{'AP_paid_' . $i} . " " . SL::DB::Manager::Chart->find_by(accno => $form->{'AP_paid_' . $i})->description
     : '';
  }
  $form->{paid_missing} =  $::form->{is_linked_bank_transaction} && $form->{invoice_obj}->forex ?
                           $form->{invoice_obj}->open_amount
                        :  $form->{invtotal_unformatted} - $form->{totalpaid};

  $form->{payment_id} = $form->{invoice_obj}->{payment_id} // $form->{payment_id};
  print $form->parse_html_template('ap/form_header', {
    today => DateTime->today,
    currencies => SL::DB::Manager::Currency->get_all_sorted,
    payment_terms => SL::DB::Manager::PaymentTerm->get_all_sorted(query => [ or => [ obsolete => 0, id => $form->{payment_id}*1 ]]),
  });

  $main::lxdebug->leave_sub();
}

sub form_footer {
  $::lxdebug->enter_sub;

  _assert_access();

  my $num_due;
  my $num_follow_ups;
  if ($::form->{id}) {
    my $follow_ups = FU->follow_ups('trans_id' => $::form->{id}, 'not_done' => 1);

    if (@{ $follow_ups }) {
      $num_due        = sum map { $_->{due} * 1 } @{ $follow_ups };
      $num_follow_ups = scalar @{ $follow_ups }
    }
  }

  my $transdate = $::form->datetonum($::form->{transdate}, \%::myconfig);
  my $closedto  = $::form->datetonum($::form->{closedto},  \%::myconfig);

  my $storno = $::form->{id}
            && !IS->has_storno(\%::myconfig, $::form, 'ap')
            && !IS->is_storno( \%::myconfig, $::form, 'ap', $::form->{id})
            && ($::form->{totalpaid} == 0 || $::form->{totalpaid} eq '');

  $::form->header;
  print $::form->parse_html_template('ap/form_footer', {
    num_due           => $num_due,
    num_follow_ups    => $num_follow_ups,
  });

  $::lxdebug->leave_sub;
}

sub mark_as_paid {
  $::auth->assert('ap_transactions');

  SL::DB::PurchaseInvoice->new(id => $::form->{id})->load->mark_as_paid;

  $::form->redirect($::locale->text("Marked as paid"));
}

sub block_or_unblock_sepa_transfer {
  $::auth->assert('ap_transactions');

  my $invoice = SL::DB::PurchaseInvoice->new(id => $::form->{id})->load;
  $invoice->update_attributes(is_sepa_blocked => 0) if  $::form->{unblock_sepa} &&  $invoice->is_sepa_blocked;
  $invoice->update_attributes(is_sepa_blocked => 1) if !$::form->{unblock_sepa} && !$invoice->is_sepa_blocked;

  $::form->redirect($::form->{unblock_sepa} ? t8('Bank transfer via SEPA is unblocked') : t8('Bank transfer via SEPA is blocked'));
}

sub show_draft {
  $::form->{transdate} = DateTime->today_local->to_kivitendo if !$::form->{transdate};
  $::form->{gldate}    = $::form->{transdate} if !$::form->{gldate};
  $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST())->token;
  update();
}

sub update {
  my %params = @_;

  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('ap_transactions');

  my $display = shift;

  $form->{invtotal} = 0;

  delete @{ $form }{ grep { m/^tax_\d+$/ } keys %{ $form } };

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(exchangerate creditlimit creditremaining);

  my @flds  = qw(amount AP_amount_chart_id projectnumber oldprojectnumber project_id taxchart tax);
  my $count = 0;
  my (@a, $j, $totaltax);
  for my $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} = $form->parse_amount(\%myconfig, $form->{"amount_$i"});
    if ($form->{"amount_$i"} || $params{keep_rows_without_amount}) {
      push @a, {};
      $j = $#a;
      my ($taxkey, $rate) = split(/--/, $form->{"taxchart_$i"});

      # calculate tax exactly the same way as AP in post_transaction via form->calculate_tax
      my $tmpnetamount;
      ($tmpnetamount,$form->{"tax_$i"}) = $form->calculate_tax($form->{"amount_$i"},$rate,$form->{taxincluded},2);

      my $tax = SL::DB::Manager::Tax->find_by(id => $taxkey);
      $totaltax += ($tax->reverse_charge_chart_id) ? 0 : $form->{"tax_$i"};

      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }
  $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});

  map { $form->{invtotal} += $form->{"amount_$_"} } (1 .. $form->{rowcount});

  $form->{invdate} = $form->{transdate};

  if (($form->{previous_vendor_id} || $form->{vendor_id}) != $form->{vendor_id}) {
    IR->get_vendor(\%::myconfig, $form);

    my $vendor = SL::DB::Vendor->load_cached($form->{vendor_id});

    # reset payment to new vendor
    $form->{payment_id} = $vendor->payment_id;

    if (($form->{rowcount} == 1) && ($form->{amount_1} == 0)) {
      my $last_used_ap_chart = $vendor->last_used_ap_chart;
      $form->{"AP_amount_chart_id_1"} = $last_used_ap_chart->id if $last_used_ap_chart;
    }
  }

  $form->{rowcount} = $count + ($params{dont_add_new_row} ? 0 : 1);

  $form->{invtotal} =
    ($form->{taxincluded}) ? $form->{invtotal} : $form->{invtotal} + $totaltax;

  my $totalpaid;
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      map {
        $form->{"${_}_$i"} =
          $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
      } qw(paid exchangerate);

      $totalpaid += $form->{"paid_$i"};

      $form->{"forex_$i"}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell');
      $form->{"exchangerate_$i"} = $form->{"forex_$i"} if $form->{"forex_$i"};
    }
  }

  $form->{creditremaining} -=
    ($form->{invtotal} - $totalpaid + $form->{oldtotalpaid} -
     $form->{oldinvtotal});
  $form->{oldinvtotal}  = $form->{invtotal};
  $form->{oldtotalpaid} = $totalpaid;

  display_form();

  $main::lxdebug->leave_sub();
}


sub post_payment {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('ap_transactions');
  $form->mtime_ischanged('ap');

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  my $invdate = $form->datetonum($form->{transdate}, \%myconfig);

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      my $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post transaction above the maximum future booking date!'))
        if ($form->date_max_future($form->{"datepaid_$i"}, \%myconfig));

      #Zusätzlich noch das Buchungsdatum in die Bücherkontrolle einbeziehen
      # (Dient zur Prüfung ob ZE oder ZA geprüft werden soll)
      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($form->date_closed($form->{"datepaid_$i"})  && !$form->date_closed($form->{"gldate_$i"}, \%myconfig));

      if ($form->{defaultcurrency} && ($form->{currency} ne $form->{defaultcurrency})) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($invdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  ($form->{AP})      = split /--/, $form->{AP};
  ($form->{AP_paid}) = split /--/, $form->{AP_paid};
  if (AP->post_payment(\%myconfig, \%$form)) {
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

  $main::auth->assert('ap_transactions');
  $form->mtime_ischanged('ap');

  my ($inline) = @_;

  # check if there is a vendor, invoice, due date and invnumber
  $form->isblank("transdate",   $locale->text("Invoice Date missing!"));
  $form->isblank("duedate",     $locale->text("Due Date missing!"));
  $form->isblank("vendor_id",   $locale->text('Vendor missing!'));
  $form->isblank("invnumber",   $locale->text('Invoice Number missing!'));
  $form->isblank("AP_chart_id", $locale->text('No contra account selected!'));

  if ($myconfig{mandatory_departments} && !$form->{department_id}) {
    $form->{saved_message} = $::locale->text('You have to specify a department.');
    update();
    exit;
  }

  my $closedto  = $form->datetonum($form->{closedto},  \%myconfig);
  my $transdate = $form->datetonum($form->{transdate}, \%myconfig);

  $form->error($locale->text('Cannot post transaction above the maximum future booking date!'))
    if ($form->date_max_future($form->{"transdate"}, \%myconfig));
  $form->error($locale->text('Cannot post transaction for a closed period!')) if ($form->date_closed($form->{"transdate"}, \%myconfig));

  my $zero_amount_posting = 1;
  for my $i (1 .. $form->{rowcount}) {

    # no taxincluded for reverse charge
    my ($used_tax_id) = split(/--/, $form->{"taxchart_$i"});
    my $tax = SL::DB::Manager::Tax->find_by(id => $used_tax_id);
    # mark entry
    if ($tax->reverse_charge_chart_id) {
      $form->error($locale->text('Cannot Post AP transaction with tax included!')) if $form->{taxincluded};
      $form->{"reverse_charge_$i"} = 1;
    }

    if ($form->parse_amount(\%myconfig, $form->{"amount_$i"})) {
      $zero_amount_posting = 0;
    }
  }

  $form->error($locale->text('Zero amount posting!')) if $zero_amount_posting;

  if ($form->{defaultcurrency} && ($form->{currency} ne $form->{defaultcurrency})) {
    $form->isblank("exchangerate", $locale->text('Exchangerate missing!'));
    $form->error($locale->text('Cannot post invoice with negative exchange rate'))
      unless ($form->parse_amount(\%myconfig, $form->{"exchangerate"}) > 0);
  }

  delete($form->{AP});

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      my $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post transaction above the maximum future booking date!'))
      if ($form->date_max_future($form->{"datepaid_$i"}, \%myconfig));

      #Zusätzlich noch das Buchungsdatum in die Bücherkontrolle einbeziehen
      # (Dient zur Prüfung ob ZE oder ZA geprüft werden soll)
      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($form->date_closed($form->{"datepaid_$i"})  && !$form->date_closed($form->{"gldate_$i"}, \%myconfig));

      if ($form->{defaultcurrency} && ($form->{currency} ne $form->{defaultcurrency})) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($transdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }

    }
  }

  # if old vendor ne vendor redo form
  if (($form->{previous_customer_id} || $form->{customer_id}) != $form->{customer_id}) {
    &update;
    $::dispatcher->end_request;
  }
  $form->{storno}       = 0;

  if (AP->post_transaction(\%myconfig, \%$form)) {
    # create webdav folder
    if ($::instance_conf->get_webdav) {
      SL::Webdav->new(type     => 'accounts_payable',
                      number   => $form->{invnumber},
                     )->webdav_path;
    }
    # saving the history
    if(!exists $form->{addition} && $form->{id} ne "") {
      $form->{snumbers}  = qq|invnumber_| . $form->{invnumber};
      $form->{addition}  = "POSTED";
      $form->{what_done} = "invoice";
      $form->save_history;
    }
    # save zugferd file
    my $file_name = delete $form->{zugferd_session_file};
    if ($file_name) {
      my $file = SL::SessionFile->new($file_name, mode => '<');
      if (!$file->fh) {
        SL::Helper::Flash::flash_later('error',
          t8('Could not open ZUGFeRD file for reading: #1', $@));
      } else {

        # copy file to webdav folder
        if ($form->{invnumber} && $::instance_conf->get_webdav_documents) {
          my $webdav = SL::Webdav->new(
            type     => 'accounts_payable',
            number   => $form->{invnumber},
          );
          my $webdav_file = SL::Webdav::File->new(
            webdav => $webdav,
            filename => $file_name,
          );
          eval {
            $webdav_file->store(file => $file->file_name());
            1;
          } or do {
            $form->{zugferd_session_file} = $file_name;
            SL::Helper::Flash::flash_later('error',
              t8('Storing the ZUGFeRD file to the WebDAV folder failed: #1', $@));
          };
        }
        if ($form->{id} && $::instance_conf->get_doc_storage) {
          eval {
            SL::File->save(
              object_id     => $form->{id},
              object_type   => 'purchase_invoice',
              mime_type     => 'application/pdf',
              source        => 'uploaded',
              file_type     => 'document',
              file_name     => $file_name,
              file_path     => $file->file_name(),
            );
            1;
          } or do {
            $form->{zugferd_session_file} = $file_name;
            SL::Helper::Flash::flash_later('error',
              t8('Storing the ZUGFeRD file in the storage backend failed: #1', $@));
          };
        }
      }
    }

    if ($form->{email_journal_id}) {
      my $ap_transaction = SL::DB::PurchaseInvoice->new(id => $form->{id})->load;
      my $email_journal = SL::DB::EmailJournal->new(
        id => delete $form->{email_journal_id}
      )->load;
      $email_journal->link_to_record_with_attachment($ap_transaction, delete $::form->{email_attachment_id});
    }

    if (!$inline) {
      my $msg = $locale->text("AP transaction '#1' posted (ID: #2)", $form->{invnumber}, $form->{id});
      if ($form->{callback} =~ /BankTransaction/) {
        # no restore_from_session_id needed. we like to have a newly generated
        # list of invoices for bank transactions
        SL::Helper::Flash::flash_later('info', $msg);
        print $form->redirect_header($form->{callback});
        $::dispatcher->end_request;
      } elsif ($form->{callback} =~ /ScanQRCode/) {
        # callback/redirect when coming from mobile view (swiss qr bill scan)
        print $form->redirect_header(build_std_url(
          "script=controller.pl",
          'action=ScanQRBill/scan_view',
          'transaction_success=1',
          'invnumber=' . E($form->{invnumber})
        ));
        $::dispatcher->end_request;
      } elsif ('doc-tab' eq $form->{after_action}) {
        # Redirect with callback containing a fragment does not work (by now)
        # because the callback info is stored in the session an parsing the
        # callback parameters does not support fragments (see SL::Form::redirect).
        # So use flash_later for the message and redirect_headers for redirecting.
        my $add_doc_url = build_std_url("script=ap.pl", 'action=edit', 'id=' . E($form->{id}), 'fragment=ui-tabs-docs');
        SL::Helper::Flash::flash_later('info', $msg);
        print $form->redirect_header($add_doc_url);
        $::dispatcher->end_request;
      } elsif ('callback' eq $form->{after_action}) {
        my $callback = $form->{callback}
          || "controller.pl?action=LoginScreen/user_login";
        SL::Helper::Flash::flash_later('info', $msg);
        print $form->redirect_header($callback);
        $::dispatcher->end_request;
      } else {
        $form->redirect($msg);
      }
    }

  } else {
    $form->error($locale->text('Cannot post transaction!'));
  }

  $main::lxdebug->leave_sub();
}

sub use_as_new {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('ap_transactions');

  $form->{email_journal_id}    = delete $form->{workflow_email_journal_id};
  $form->{email_attachment_id} = delete $form->{workflow_email_attachment_id};
  $form->{callback}            = delete $form->{workflow_email_callback};

  map { delete $form->{$_} } qw(printed emailed queued invnumber deliverydate id datepaid_1 gldate_1 acc_trans_id_1 source_1 memo_1 paid_1 exchangerate_1 AP_paid_1 storno convert_from_oe_id);
  $form->{paidaccounts} = 1;
  $form->{rowcount}--;

  my $today          = DateTime->today_local;
  $form->{transdate} = $today->to_kivitendo;
  $form->{duedate}   = $form->{transdate};

  if ($form->{vendor_id}) {
    my $payment_terms = SL::DB::Vendor->load_cached($form->{vendor_id})->payment;
    $form->{duedate}  = $payment_terms->calc_date(reference_date => $today)->to_kivitendo if $payment_terms;
  }

  $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST())->token;

  &update;

  $main::lxdebug->leave_sub();
}

sub delete {
  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('ap_transactions');

  if (AP->delete_transaction(\%myconfig, \%$form)) {
    # saving the history
    if(!exists $form->{addition}) {
      $form->{snumbers}  = qq|invnumber_| . $form->{invnumber};
      $form->{addition}  = "DELETED";
      $form->{what_done} = "invoice";
      $form->save_history;
    }
    # /saving the history
    $form->redirect($locale->text('Transaction deleted!'));
  }
  $form->error($locale->text('Cannot delete transaction!'));
}

sub search {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{title} = $locale->text('Vendor Invoices & AP Transactions');

  $::form->{ALL_DEPARTMENTS}   = SL::DB::Manager::Department ->get_all_sorted;
  $::form->{ALL_TAXZONES}      = SL::DB::Manager::TaxZone    ->get_all_sorted;
  $::form->{ALL_PAYMENT_TERMS} = SL::DB::Manager::PaymentTerm->get_all_sorted;

  # constants and subs for template
  $form->{vc_keys}   = sub { "$_[0]->{name}--$_[0]->{id}" };

  $::request->layout->add_javascripts("autocomplete_project.js");

  setup_ap_search_action_bar();

  $form->header;
  print $form->parse_html_template('ap/search', { %myconfig });

  $main::lxdebug->leave_sub();
}

sub create_subtotal_row {
  $main::lxdebug->enter_sub();

  my ($totals, $columns, $column_alignment, $subtotal_columns, $class) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => $column_alignment->{$_}, } } @{ $columns } };

  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, 2) } @{ $subtotal_columns };

  $row->{tax}->{data} = $form->format_amount(\%myconfig, $totals->{amount} - $totals->{netamount}, 2);

  map { $totals->{$_} = 0 } @{ $subtotal_columns };

  $main::lxdebug->leave_sub();

  return $row;
}

sub ap_transactions {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  report_generator_set_default_sort('transdate', 1);

  AP->ap_transactions(\%myconfig, \%$form);

  $form->{title} = $locale->text('Vendor Invoices & AP Transactions');

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @columns =
    qw(transdate id type invnumber ordnumber name netamount tax amount paid datepaid
       due duedate transaction_description notes intnotes employee globalprojectnumber department
       vendornumber country ustid taxzone payment_terms charts debit_chart direct_debit
       insertdate items);

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, "l_subtotal", qw(open closed vendor invnumber ordnumber transaction_description notes intnotes project_id
                                           transdatefrom transdateto duedatefrom duedateto datepaidfrom datepaidto
                                           parts_partnumber parts_description department_id taxzone_id payment_id
                                           fulltext insertdatefrom insertdateto);

  my $href = build_std_url('action=ap_transactions', grep { $form->{$_} } @hidden_variables);

  my %column_defs = (
    'transdate'               => { 'text' => $locale->text('Date'), },
    'id'                      => { 'text' => $locale->text('ID'), },
    'type'                    => { 'text' => $locale->text('Type'), },
    'invnumber'               => { 'text' => $locale->text('Invoice'), },
    'ordnumber'               => { 'text' => $locale->text('Order'), },
    'name'                    => { 'text' => $locale->text('Vendor'), },
    'netamount'               => { 'text' => $locale->text('Amount'), },
    'tax'                     => { 'text' => $locale->text('Tax'), },
    'amount'                  => { 'text' => $locale->text('Total'), },
    'paid'                    => { 'text' => $locale->text('Paid'), },
    'datepaid'                => { 'text' => $locale->text('Date Paid'), },
    'due'                     => { 'text' => $locale->text('Amount Due'), },
    'duedate'                 => { 'text' => $locale->text('Due Date'), },
    'transaction_description' => { 'text' => $locale->text('Transaction description'), },
    'notes'                   => { 'text' => $locale->text('Notes'), },
    'intnotes'                => { 'text' => $locale->text('Internal Notes'), },
    'employee'                => { 'text' => $locale->text('Employee'), },
    'globalprojectnumber'     => { 'text' => $locale->text('Document Project Number'), },
    'department'              => { 'text' => $locale->text('Department'), },
    'vendornumber'            => { 'text' => $locale->text('Vendor Number'), },
    'country'                 => { 'text' => $locale->text('Country'), },
    'ustid'                   => { 'text' => $locale->text('USt-IdNr.'), },
    'taxzone'                 => { 'text' => $locale->text('Tax rate'), },
    'payment_terms'           => { 'text' => $locale->text('Payment Terms'), },
    'charts'                  => { 'text' => $locale->text('Chart'), },
    'debit_chart'             => { 'text' => $locale->text('Debit Account'), },
    'direct_debit'            => { 'text' => $locale->text('direct debit'), },
    'insertdate'              => { 'text' => $locale->text('Insert Date'), },
    'items'                   => { 'text' => $locale->text('Positions'), },
  );

foreach my $name (qw(id transdate duedate invnumber ordnumber name datepaid employee shipvia transaction_description direct_debit department taxzone insertdate intnotes)) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=$name&sortdir=$sortdir";
  }

  my %column_alignment = map { $_ => 'right' } qw(netamount tax amount paid due);

  $form->{"l_type"} = "Y";
  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('ap_transactions', @hidden_variables, qw(sort sortdir));

  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  my $department_description;
  $department_description = SL::DB::Manager::Department->find_by(id => $form->{department_id})->description if $form->{department_id};
  my $project_description;
  $project_description = SL::DB::Manager::Project->find_by(id => $form->{project_id})->description if $form->{project_id};

  my @options;
  push @options, $locale->text('Vendor')                  . " : $form->{vendor}"                         if ($form->{vendor});
  push @options, $locale->text('Contact Person')          . " : $form->{cp_name}"                        if ($form->{cp_name});
  push @options, $locale->text('Department')              . " : $department_description"                 if ($form->{department_id});
  push @options, $locale->text('Project')                 . " : $project_description"                    if ($project_description);
  push @options, $locale->text('Invoice Number')          . " : $form->{invnumber}"                      if ($form->{invnumber});
  push @options, $locale->text('Order Number')            . " : $form->{ordnumber}"                      if ($form->{ordnumber});
  push @options, $locale->text('Notes')                   . " : $form->{notes}"                          if ($form->{notes});
  push @options, $locale->text('Internal Notes')          . " : $form->{intnotes}"                       if $form->{intnotes};
  push @options, $locale->text('Transaction description') . " : $form->{transaction_description}"        if ($form->{transaction_description});
  push @options, $locale->text('Part Description')        . " : $form->{parts_description}"              if $form->{parts_description};
  push @options, $locale->text('Part Number')             . " : $form->{parts_partnumber}"               if $form->{parts_partnumber};
  push @options, $locale->text('Full Text')               . " : $form->{fulltext}"                       if ($form->{fulltext});
  push @options, $locale->text('From')                                      . " " . $locale->date(\%myconfig, $form->{transdatefrom},  1) if ($form->{transdatefrom});
  push @options, $locale->text('Bis')                                       . " " . $locale->date(\%myconfig, $form->{transdateto},    1) if ($form->{transdateto});
  push @options, $locale->text('Due Date')    . " " . $locale->text('from') . " " . $locale->date(\%myconfig, $form->{duedatefrom},    1) if ($form->{duedatefrom});
  push @options, $locale->text('Due Date')    . " " . $locale->text('to')   . " " . $locale->date(\%myconfig, $form->{duedateto},      1) if ($form->{duedateto});
  push @options, $locale->text('Date Paid')   . " " . $locale->text('from') . " " . $locale->date(\%myconfig, $form->{datepaidfrom},   1) if ($form->{datepaidfrom});
  push @options, $locale->text('Date Paid')   . " " . $locale->text('to')   . " " . $locale->date(\%myconfig, $form->{datepaidto},     1) if ($form->{datepaidto});
  push @options, $locale->text('Insert Date') . " " . $locale->text('from') . " " . $locale->date(\%myconfig, $form->{insertdatefrom}, 1) if ($form->{insertdatefrom});
  push @options, $locale->text('Insert Date') . " " . $locale->text('to')   . " " . $locale->date(\%myconfig, $form->{insertdateto},   1) if ($form->{insertdateto});
  push @options, $locale->text('Open')                                                                   if ($form->{open});
  push @options, $locale->text('Closed')                                                                 if ($form->{closed});
  if ($form->{payment_id}) {
    my $payment_term = SL::DB::Manager::PaymentTerm->find_by( id => $form->{payment_id} );
    push @options, $locale->text('Payment Term') . " : " . $payment_term->description;
  }

  $report->set_options('top_info_text'        => join("\n", @options),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $locale->text('vendor_invoice_list') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $href .= "&sort=$form->{sort}";

  # escape callback for href
  my $callback = $form->escape($href);

  my @subtotal_columns = qw(netamount amount paid due);

  my %totals    = map { $_ => 0 } @subtotal_columns;
  my %subtotals = map { $_ => 0 } @subtotal_columns;

  my $idx = 0;

  foreach my $ap (@{ $form->{AP} }) {
    $ap->{tax} = $ap->{amount} - $ap->{netamount};
    $ap->{due} = $ap->{amount} - $ap->{paid};

    map { $subtotals{$_} += $ap->{$_};
          $totals{$_}    += $ap->{$_} } @subtotal_columns;

    map { $ap->{$_} = $form->format_amount(\%myconfig, $ap->{$_}, 2) } qw(netamount tax amount paid due);

    my $is_storno  = $ap->{storno} &&  $ap->{storno_id};
    my $has_storno = $ap->{storno} && !$ap->{storno_id};

    if ($ap->{invoice}) {
      $ap->{type} =
          $has_storno       ? $locale->text("Invoice with Storno (abbreviation)")
        : $is_storno        ? $locale->text("Storno (one letter abbreviation)")
        :                     $locale->text("Invoice (one letter abbreviation)");
    } else {
      $ap->{type} =
          $has_storno       ? $locale->text("AP Transaction with Storno (abbreviation)")
        : $is_storno        ? $locale->text("AP Transaction Storno (one letter abbreviation)")
        :                     $locale->text("AP Transaction (abbreviation)");
    }

    $ap->{direct_debit} = $ap->{direct_debit} ? $::locale->text('yes') : $::locale->text('no');

    my $row = { };

    foreach my $column (@columns) {
      next if ($column eq 'items');

      $row->{$column} = {
        'data'  => $ap->{$column},
        'align' => $column_alignment{$column},
      };
    }

    $row->{invnumber}->{link} = build_std_url("script=" . ($ap->{invoice} ? 'ir.pl' : 'ap.pl'), 'action=edit')
      . "&id=" . E($ap->{id}) . "&callback=${callback}";

    if ($form->{l_items}) {
      my $items = SL::DB::Manager::InvoiceItem->get_all_sorted(where => [id => $ap->{item_ids}]);
      $row->{items}->{raw_data}  = SL::Presenter::ItemsList::items_list($items)               if lc($report->{options}->{output_format}) eq 'html';
      $row->{items}->{data}      = SL::Presenter::ItemsList::items_list($items, as_text => 1) if lc($report->{options}->{output_format}) ne 'html';
    }

    my $row_set = [ $row ];

    if (($form->{l_subtotal} eq 'Y')
        && (($idx == (scalar @{ $form->{AP} } - 1))
            || ($ap->{ $form->{sort} } ne $form->{AP}->[$idx + 1]->{ $form->{sort} }))) {
      push @{ $row_set }, create_subtotal_row(\%subtotals, \@columns, \%column_alignment, \@subtotal_columns, 'listsubtotal');
    }

    $report->add_data($row_set);

    $idx++;
  }

  $report->add_separator();
  $report->add_data(create_subtotal_row(\%totals, \@columns, \%column_alignment, \@subtotal_columns, 'listtotal'));

  setup_ap_transactions_action_bar();
  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub storno {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('ap_transactions');

  if (IS->has_storno(\%myconfig, $form, 'ap')) {
    $form->{title} = $locale->text("Cancel Accounts Payables Transaction");
    $form->error($locale->text("Transaction has already been cancelled!"));
  }

  $form->error($locale->text('Cannot post storno for a closed period!'))
    if ( $form->date_closed($form->{transdate}, \%myconfig));

  AP->storno($form, \%myconfig, $form->{id});

  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers}  = qq|invnumber_| . $form->{invnumber};
    $form->{addition}  = "STORNO";
    $form->{what_done} = "invoice";
    $form->save_history;
  }
  # /saving the history

  $form->redirect(sprintf $locale->text("Transaction %d cancelled."), $form->{storno_id});

  $main::lxdebug->leave_sub();
}

sub add_from_purchase_order {
  $main::auth->assert('ap_transactions');

  return if !$::form->{id};

  my $order_id = delete $::form->{id};
  my $order    = SL::DB::Order->new(id => $order_id)->load(with => [ 'vendor', 'currency', 'payment_terms' ]);

  return if $order->type ne 'purchase_order';

  my $today                     = DateTime->today_local;
  $::form->{title}                   = "Add";
  $::form->{vc}                      = 'vendor';
  $::form->{vendor_id}               = $order->customervendor->id;
  $::form->{vendor}                  = $order->vendor->name;
  $::form->{convert_from_oe_id}      = $order->id;
  $::form->{globalproject_id}        = $order->globalproject_id;
  $::form->{ordnumber}               = $order->number;
  $::form->{department_id}           = $order->department_id;
  $::form->{transaction_description} = $order->transaction_description;
  $::form->{currency}                = $order->currency->name;
  $::form->{taxincluded}             = 1; # we use amount below, so tax is included
  $::form->{transdate}               = $today->to_kivitendo;
  $::form->{duedate}                 = $today->to_kivitendo;
  $::form->{duedate}                 = $order->payment_terms->calc_date(reference_date => $today)->to_kivitendo if $order->payment_terms;
  $::form->{deliverydate}            = $order->reqdate->to_kivitendo                                            if $order->reqdate;
  create_links();

  my $config_po_ap_workflow_chart_id = $::instance_conf->get_workflow_po_ap_chart_id;

  my ($first_taxchart, $default_taxchart, $taxchart_to_use);
  my @taxcharts = ();
  @taxcharts    = GL->get_active_taxes_for_chart($config_po_ap_workflow_chart_id, $::form->{transdate}) if (defined $config_po_ap_workflow_chart_id);
  foreach my $item (@taxcharts) {
    $first_taxchart   //= $item;
    $default_taxchart   = $item if $item->{is_default};
  }
  $taxchart_to_use      = $default_taxchart // $first_taxchart;

  my %pat = $order->calculate_prices_and_taxes;
  my $row = 1;
  foreach my $amount_chart (keys %{$pat{amounts}}) {
    my $tax = SL::DB::Manager::Tax->find_by(id => $pat{amounts}->{$amount_chart}->{tax_id});
    # If tax chart from order for this amount is active, use it. Use default or first tax chart for selected chart else.
    if (defined $config_po_ap_workflow_chart_id) {
      $taxchart_to_use = (first {$_->{id} == $tax->id} @taxcharts) // $taxchart_to_use;
    } else {
      $taxchart_to_use = $tax;
    }

    $::form->{"AP_amount_chart_id_$row"}          = $config_po_ap_workflow_chart_id // $amount_chart;
    $::form->{"previous_AP_amount_chart_id_$row"} = $::form->{"AP_amount_chart_id_$row"};
    $::form->{"amount_$row"}                      = $::form->format_amount(\%::myconfig, $pat{amounts}->{$amount_chart}->{amount} * (1 + $tax->rate), 2);
    $::form->{"taxchart_$row"}                    = $taxchart_to_use->id . '--' . $taxchart_to_use->rate;
    $::form->{"project_id_$row"}                  = $order->globalproject_id;

    $row++;
  }

  my $last_used_ap_chart               = SL::DB::Vendor->load_cached($::form->{vendor_id})->last_used_ap_chart;
  $::form->{"AP_amount_chart_id_$row"} = $last_used_ap_chart->id if $last_used_ap_chart;
  $::form->{rowcount}                  = $row;

  $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST())->token;

  update(
    keep_rows_without_amount => 1,
    dont_add_new_row         => 1,
  );
}

sub add_from_email_journal {
  die "No 'email_journal_id' was given." unless ($::form->{email_journal_id});
  &add;
}

sub load_record_template_from_email_journal {
  die "No 'email_journal_id' was given." unless ($::form->{email_journal_id});
  &load_record_template;
}

sub edit_with_email_journal_workflow {
  my ($self) = @_;
  die "No 'email_journal_id' was given." unless ($::form->{email_journal_id});
  $::form->{workflow_email_journal_id}    = delete $::form->{email_journal_id};
  $::form->{workflow_email_attachment_id} = delete $::form->{email_attachment_id};
  $::form->{workflow_email_callback}      = delete $::form->{callback};

  &edit;
}

sub setup_ap_search_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $::locale->text('Search'),
        submit    => [ '#form', { action => "ap_transactions" } ],
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}

sub setup_ap_transactions_action_bar {
  my %params          = @_;
  my $may_edit_create = $::auth->assert('ap_transactions', 1);

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [ t8('Add') ],
        link => [
          t8('Purchase Invoice'),
          link     => [ 'ir.pl?action=add' ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,

        ],
        link => [
          t8('AP Transaction'),
          link     => [ 'ap.pl?action=add' ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
      ], # end of combobox "Add"
    );
  }
}

sub setup_ap_display_form_action_bar {
  my $transdate               = $::form->datetonum($::form->{transdate}, \%::myconfig);
  my $closedto                = $::form->datetonum($::form->{closedto},  \%::myconfig);
  my $is_closed               = $transdate <= $closedto;

  my $change_never            = $::instance_conf->get_ap_changeable == 0;
  my $change_on_same_day_only = $::instance_conf->get_ap_changeable == 2 && ($::form->current_date(\%::myconfig) ne $::form->{gldate});

  my $is_storno               = IS->is_storno(\%::myconfig, $::form, 'ap', $::form->{id});
  my $has_storno              = IS->has_storno(\%::myconfig, $::form, 'ap');

  my $may_edit_create         = $::auth->assert('ap_transactions', 1);

  my $has_sepa_exports;
  my $is_sepa_blocked;
  if ($::form->{id}) {
    my $invoice = SL::DB::Manager::PurchaseInvoice->find_by(id => $::form->{id});
    $has_sepa_exports = 1 if ($invoice->find_sepa_export_items()->[0]);
    $is_sepa_blocked  = !!$invoice->is_sepa_blocked;
  }

  my $is_linked_bank_transaction;
  if ($::form->{id}
      && SL::DB::Manager::BankTransactionAccTrans->find_by(ap_id => $::form->{id})) {

    $is_linked_bank_transaction = 1;
  }
  my $is_linked_gl_transaction;
  if ($::form->{id} && SL::DB::Manager::ApGl->find_by(ap_id => $::form->{id})) {
    $is_linked_gl_transaction = 1;
  }
  # add readonly state in $::form
  $::form->{readonly} = !$may_edit_create                           ? 1
                      : $is_closed                                  ? 1
                      : $is_storno                                  ? 1
                      : $has_storno                                 ? 1
                      : ($::form->{id} && $change_never)            ? 1
                      : ($::form->{id} && $change_on_same_day_only) ? 1
                      : $is_linked_bank_transaction                 ? 1
                      : $has_sepa_exports                           ? 1
                      : 0;
  # and is_linked_bank_transaction
  $::form->{is_linked_bank_transaction} = $is_linked_bank_transaction;

  my $create_post_action = sub {
    # $_[0]: description
    # $_[1]: after_action
    action => [

      $_[0],
      submit   => [ '#form', { action => "post", after_action => $_[1] } ],
      checks   => [ 'kivi.validate_form', 'kivi.AP.check_fields_before_posting', 'kivi.AP.check_duplicate_invnumber' ],
      disabled => !$may_edit_create                           ? t8('You must not change this AP transaction.')
                : $is_closed                                  ? t8('The billing period has already been locked.')
                : $is_storno                                  ? t8('A canceled invoice cannot be posted.')
                : ($::form->{id} && $change_never)            ? t8('Changing invoices has been disabled in the configuration.')
                : ($::form->{id} && $change_on_same_day_only) ? t8('Invoices can only be changed on the day they are posted.')
                : $is_linked_bank_transaction                 ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                :                                               undef,
    ],
  };

  my @post_entries;
  if ($::instance_conf->get_ap_add_doc && $::instance_conf->get_doc_storage) {
    @post_entries = ( $create_post_action->(t8('Post'), 'doc-tab'),
                      $create_post_action->(t8('Post and new booking')) );
  } elsif ($::instance_conf->get_doc_storage) {
    @post_entries = ( $create_post_action->(t8('Post')),
                      $create_post_action->(t8('Post and upload document'), 'doc-tab') );
  } else {
    @post_entries = ( $create_post_action->(t8('Post')) );
  }
  push @post_entries, $create_post_action->(t8('Post and Close'), 'callback');

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => "update" } ],
        id        => 'update_button',
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
        disabled  => !$may_edit_create ? t8('You must not change this AP transaction.') : undef,
      ],
      combobox => [
        @post_entries,
        action => [
          t8('Post Payment'),
          submit   => [ '#form', { action => "post_payment" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create           ? t8('You must not change this AP transaction.')
                    : !$::form->{id}              ? t8('This invoice has not been posted yet.')
                    : $is_linked_bank_transaction ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                               undef,
        ],
        action => [ $is_sepa_blocked ? t8('Unblock Bank transfer via SEPA') : t8('Block Bank transfer via SEPA'),
          submit   => [ '#form', { action => "block_or_unblock_sepa_transfer", unblock_sepa => !!$is_sepa_blocked } ],
          disabled => !$may_edit_create ? t8('You must not change this AP transaction.')
                    : !$::form->{id}    ? t8('This invoice has not been posted yet.')
                    :                     undef,
        ],
        action => [ t8('Mark as paid'),
          submit   => [ '#form', { action => "mark_as_paid" } ],
          confirm  => t8('This will remove the invoice from showing as unpaid even if the unpaid amount does not match the amount. Proceed?'),
          disabled => !$may_edit_create ? t8('You must not change this AP transaction.')
                    : !$::form->{id}    ? t8('This invoice has not been posted yet.')
                    :                     undef,
          only_if  => $::instance_conf->get_is_show_mark_as_paid,
        ],
      ], # end of combobox "Post"

      combobox => [
        action => [ t8('Storno'),
          submit   => [ '#form', { action => "storno" } ],
          checks   => [ 'kivi.validate_form', 'kivi.AP.check_fields_before_posting' ],
          confirm  => t8('Do you really want to cancel this invoice?'),
          disabled => !$may_edit_create    ? t8('You must not change this AP transaction.')
                    : !$::form->{id}       ? t8('This invoice has not been posted yet.')
                    : $has_storno          ? t8('This invoice has been canceled already.')
                    : $is_storno           ? t8('Reversal invoices cannot be canceled.')
                    : $::form->{totalpaid} ? t8('Invoices with payments cannot be canceled.')
                    : $has_sepa_exports    ? t8('This invoice has been linked with a sepa export, undo this first.')
                    : $is_linked_gl_transaction   ? t8('This transaction is linked with a gl transaction. Please delete the ap transaction booking if needed.')
                    : $is_linked_bank_transaction ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                        undef,
        ],
        action => [ t8('Delete'),
          submit   => [ '#form', { action => "delete" } ],
          confirm  => t8('Do you really want to delete this object?'),
          disabled => !$may_edit_create           ? t8('You must not change this AP transaction.')
                    : !$::form->{id}              ? t8('This invoice has not been posted yet.')
                    : $is_closed                  ? t8('The billing period has already been locked.')
                    : $has_sepa_exports           ? t8('This invoice has been linked with a sepa export, undo this first.')
                    : $is_linked_bank_transaction ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    # : $is_linked_gl_transaction   ? undef # linked transactions can be deleted, if period is not closed
                    : $change_never               ? t8('Changing invoices has been disabled in the configuration.')
                    : $change_on_same_day_only    ? t8('Invoices can only be changed on the day they are posted.')
                    : $has_storno                 ? t8('This invoice has been canceled already.')
                    :                               undef,
        ],
      ], # end of combobox "Storno"

      'separator',

      combobox => [
        action => [ t8('Workflow') ],
        action => [
          t8('Use As New'),
          submit   => [ '#form', { action => "use_as_new" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create ? t8('You must not change this AP transaction.')
                    : !$::form->{id}    ? t8('This invoice has not been posted yet.')
                    :                     undef,
        ],
      ], # end of combobox "Workflow"

      combobox => [
        action => [ t8('more') ],
        action => [
          t8('History'),
          call     => [ 'set_history_window', $::form->{id} * 1, 'glid' ],
          disabled => !$::form->{id} ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Follow-Up'),
          call     => [ 'follow_up_window' ],
          disabled => !$::form->{id} ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Record templates'),
          call     => [ 'kivi.RecordTemplate.popup', 'ap_transaction' ],
          disabled => !$may_edit_create ? t8('You must not change this AP transaction.') : undef,
        ],
        action => [
          t8('Drafts'),
          call     => [ 'kivi.Draft.popup', 'ap', 'invoice', $::form->{draft_id}, $::form->{draft_description} ],
          disabled => !$may_edit_create ? t8('You must not change this AP transaction.')
                    : $::form->{id}     ? t8('This invoice has already been posted.')
                    : $is_closed        ? t8('The billing period has already been locked.')
                    :                     undef,
        ],
      ], # end of combobox "more"
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}
