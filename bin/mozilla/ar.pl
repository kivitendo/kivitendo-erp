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
# Accounts Receivables
#
#======================================================================

use POSIX qw(strftime);
use List::Util qw(sum first max);
use List::UtilsBy qw(sort_by);

use SL::AR;
use SL::Controller::Base;
use SL::FU;
use SL::GL;
use SL::IS;
use SL::DB::BankTransactionAccTrans;
use SL::DB::Business;
use SL::DB::Chart;
use SL::DB::Currency;
use SL::DB::Default;
use SL::DB::Employee;
use SL::DB::Manager::Invoice;
use SL::DB::InvoiceItem;
use SL::DB::RecordTemplate;
use SL::DB::Tax;
use SL::DB::EmailJournal;
use SL::DB::ValidityToken;
use SL::Helper::Flash qw(flash flash_later);
use SL::Locale::String qw(t8);
use SL::Presenter::Tag;
use SL::Presenter::Chart;
use SL::Presenter::ItemsList;
use SL::ReportGenerator;

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

use strict;
#use warnings;

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
  return 1 if  $::auth->assert('ar_transactions', 1); # may edit all invoices
  return 0 if !$::form->{id};                         # creating new invoices isn't allowed without invoice_edit
  return 0 if !$::form->{globalproject_id};           # existing records without a project ID are not allowed
  return SL::DB::Project->new(id => $::form->{globalproject_id})->load->may_employee_view_project_invoices(SL::DB::Manager::Employee->current);
}

sub _assert_access {
  my $cache = $::request->cache('ar.pl::_assert_access');

  $cache->{_may_view_or_edit_this_invoice} = _may_view_or_edit_this_invoice()                              if !exists $cache->{_may_view_or_edit_this_invoice};
  $::form->show_generic_error($::locale->text("You do not have the permissions to access this function.")) if !       $cache->{_may_view_or_edit_this_invoice};
}

sub load_record_template {
  $::auth->assert('ar_transactions');

  # Load existing template and verify that its one for this module.
  my $template = SL::DB::RecordTemplate
    ->new(id => $::form->{id})
    ->load(
      with_object => [ qw(customer payment currency record_items record_items.chart) ],
    );

  die "invalid template type" unless $template->template_type eq 'ar_transaction';

  $template->substitute_variables;

  # Clean the current $::form before rebuilding it from the template.
  my $form_defaults = delete $::form->{form_defaults};
  delete @{ $::form }{ grep { !m{^(?:script|login)$}i } keys %{ $::form } };

  # Fill $::form from the template.
  my $today                   = DateTime->today_local;
  $::form->{title}                   = "Add";
  $::form->{currency}                = $template->currency->name;
  $::form->{direct_debit}            = $template->direct_debit;
  $::form->{globalproject_id}        = $template->project_id;
  $::form->{transaction_description} = $template->transaction_description;
  $::form->{AR_chart_id}             = $template->ar_ap_chart_id;
  $::form->{transdate}               = $today->to_kivitendo;
  $::form->{duedate}                 = $today->to_kivitendo;
  $::form->{rowcount}                = @{ $template->items };
  $::form->{paidaccounts}            = 1;
  $::form->{$_}                      = $template->$_ for qw(department_id ordnumber taxincluded employee_id notes);

  if ($template->customer) {
    $::form->{customer_id} = $template->customer_id;
    $::form->{customer}    = $template->customer->name;
    $::form->{duedate}     = $template->customer->payment->calc_date(reference_date => $today)->to_kivitendo if $template->customer->payment;
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

    $::form->{"AR_amount_chart_id_${row}"}          = $item->chart_id;
    $::form->{"previous_AR_amount_chart_id_${row}"} = $item->chart_id;
    $::form->{"amount_${row}"}                      = $::form->format_amount(\%::myconfig, $item->amount1, 2);
    $::form->{"taxchart_${row}"}                    = $item->tax_id . '--' . $tax->rate;
    $::form->{"project_id_${row}"}                  = $item->project_id;
  }

  $::form->{$_} = $form_defaults->{$_} for keys %{ $form_defaults // {} };

  flash('info', $::locale->text("The record template '#1' has been loaded.", $template->template_name));

  $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;

  update(
    keep_rows_without_amount => 1,
    dont_add_new_row         => 1,
  );
}

sub save_record_template {
  $::auth->assert('ar_transactions');

  my $template = $::form->{record_template_id} ? SL::DB::RecordTemplate->new(id => $::form->{record_template_id})->load : SL::DB::RecordTemplate->new;
  my $js       = SL::ClientJS->new(controller => SL::Controller::Base->new);
  my $new_name = $template->template_name_to_use($::form->{record_template_new_template_name});

  $js->dialog->close('#record_template_dialog');

  my @items = grep {
    $_->{chart_id} && (($_->{tax_id} // '') ne '')
  } map {
    +{ chart_id   => $::form->{"AR_amount_chart_id_${_}"},
       amount1    => $::form->parse_amount(\%::myconfig, $::form->{"amount_${_}"}),
       tax_id     => (split m{--}, $::form->{"taxchart_${_}"})[0],
       project_id => $::form->{"project_id_${_}"} || undef,
     }
  } (1..($::form->{rowcount} || 1));

  $template->assign_attributes(
    template_type           => 'ar_transaction',
    template_name           => $new_name,

    currency_id             => SL::DB::Manager::Currency->find_by(name => $::form->{currency})->id,
    ar_ap_chart_id          => $::form->{AR_chart_id}      || undef,
    customer_id             => $::form->{customer_id}      || undef,
    department_id           => $::form->{department_id}    || undef,
    project_id              => $::form->{globalproject_id} || undef,
    employee_id             => $::form->{employee_id}      || undef,
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

  $main::auth->assert('ar_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  # saving the history
  if(!exists $form->{addition} && ($form->{id} ne "")) {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
    $form->{addition} = "ADDED";
    $form->save_history;
  }
  # /saving the history

  $form->{title}    = "Add";
  $form->{callback} = "ar.pl?action=add" unless $form->{callback};

  AR->get_transdate(\%myconfig, $form);
  $form->{initial_transdate} = $form->{transdate};
  $form->{initial_customer_id} = $form->{customer_id};
  create_links(dont_save => 1);
  $form->{transdate} = $form->{initial_transdate};
  $form->{customer_id} = $form->{initial_customer_id} if $form->{initial_customer_id};

  if ($form->{customer_id}) {
    my $last_used_ar_chart = SL::DB::Customer->load_cached($form->{customer_id})->last_used_ar_chart;
    $form->{"AR_amount_chart_id_1"} = $last_used_ar_chart->id if $last_used_ar_chart;
  }

  if (!$form->{form_validity_token}) {
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;
  }

  &display_form;
  $main::lxdebug->leave_sub();
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

sub edit {
  $main::lxdebug->enter_sub();

  # Delay access check to after the invoice's been loaded in
  # "create_links" so that project-specific invoice rights can be
  # evaluated.

  my $form     = $main::form;

  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->{title} = "Edit";

  create_links();
  &display_form;

  $main::lxdebug->leave_sub();
}

sub display_form {
  $main::lxdebug->enter_sub();

  _assert_access();

  my $form     = $main::form;

  &form_header;
  &form_footer;

  $main::lxdebug->leave_sub();
}

sub _retrieve_invoice_object {
  return undef if !$::form->{id};
  return $::form->{invoice_obj} if $::form->{invoice_obj} && $::form->{invoice_obj}->id == $::form->{id};
  return SL::DB::Invoice->new(id => $::form->{id})->load;
}

sub create_links {
  $main::lxdebug->enter_sub();

  # Delay access check to after the invoice's been loaded so that
  # project-specific invoice rights can be evaluated.

  my %params   = @_;
  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->create_links("AR", \%myconfig, "customer");
  $form->{invoice_obj} = _retrieve_invoice_object();

  _assert_access();

  my %saved;
  if (!$params{dont_save}) {
    %saved = map { ($_ => $form->{$_}) } qw(direct_debit id taxincluded);
    $saved{duedate} = $form->{duedate} if $form->{duedate};
    $saved{currency} = $form->{currency} if $form->{currency};
  }

  IS->get_customer(\%myconfig, \%$form);

  $form->{$_}          = $saved{$_} for keys %saved;
  $form->{rowcount}    = 1;
  $form->{AR_chart_id} = $form->{acc_trans} && $form->{acc_trans}->{AR} ? $form->{acc_trans}->{AR}->[0]->{chart_id} : $::instance_conf->get_ar_chart_id || $form->{AR_links}->{AR}->[0]->{chart_id};

  # currencies
  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  $form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;

  # build the popup menus
  $form->{taxincluded} = ($form->{id}) ? $form->{taxincluded} : "checked";

  AR->setup_form($form);

  $form->{locked} =
    ($form->datetonum($form->{transdate}, \%myconfig) <=
     $form->datetonum($form->{closedto}, \%myconfig));

  $main::lxdebug->leave_sub();
}

sub form_header {
  $main::lxdebug->enter_sub();

  _assert_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  $form->{invoice_obj} = _retrieve_invoice_object();

  my ($title, $readonly, $exchangerate, $rows);
  my ($notes, $amount, $project);

  $form->{initial_focus} = !($form->{amount_1} * 1) ? 'customer_id' : 'row_' . $form->{rowcount};

  $title = $form->{title};
  # $locale->text('Add Accounts Receivables Transaction')
  # $locale->text('Edit Accounts Receivables Transaction')
  $form->{title} = $locale->text("$title Accounts Receivables Transaction");

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);
  if ($form->{currency} ne $form->{defaultcurrency}) {
    ($form->{exchangerate}, $form->{record_forex}) = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{transdate}, "buy", $form->{id}, 'ar');
  }


  $rows = max 2, $form->numtextrows($form->{notes}, 50);

  my @old_project_ids = grep { $_ } map { $form->{"project_id_$_"} } 1..$form->{rowcount};

  $form->get_lists("projects"  => { "key"       => "ALL_PROJECTS",
                                    "all"       => 0,
                                    "old_id"    => \@old_project_ids },
                   "charts"    => { "key"       => "ALL_CHARTS",
                                    "transdate" => $form->{transdate} },
                  );

  $form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;

  $_->{link_split} = { map { $_ => 1 } split/:/, $_->{link} } for @{ $form->{ALL_CHARTS} };

  my %project_labels = map { $_->{id} => $_->{projectnumber} } @{ $form->{"ALL_PROJECTS"} };

  my (@AR_paid_values, %AR_paid_labels, %bank_accounts);
  my $default_ar_amount_chart_id;
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
    if ($item->{link_split}{AR_amount}) {
      $default_ar_amount_chart_id //= $item->{id};

    } elsif ($item->{link_split}{AR_paid}) {
      next if $bank_accounts{$item->{accno}};
      push(@AR_paid_values, $item->{accno});
      $AR_paid_labels{$item->{accno}} = "$item->{accno}--$item->{description}";
    }
  }

  my $follow_up_vc         = $form->{customer_id} ? SL::DB::Customer->load_cached($form->{customer_id})->name : '';
  my $follow_up_trans_info =  "$form->{invnumber} ($follow_up_vc)";

  $::request->layout->add_javascripts("autocomplete_chart.js", "show_history.js", "follow_up.js", "kivi.Draft.js", "kivi.GL.js", "kivi.File.js", "kivi.RecordTemplate.js", "kivi.AR.js", "kivi.CustomerVendor.js", "kivi.Validator.js", "autocomplete_project.js");
  # get the correct date for tax
  my $transdate    = $::form->{transdate}    ? DateTime->from_kivitendo($::form->{transdate})    : DateTime->today_local;
  my $deliverydate = $::form->{deliverydate} ? DateTime->from_kivitendo($::form->{deliverydate}) : undef;
  my $taxdate      = $deliverydate ? $deliverydate : $transdate;
  # helpers for loop
  my $first_taxchart;
  my @transactions;

  for my $i (1 .. $form->{rowcount}) {
    my $transaction = {
      amount     => $form->{"amount_$i"},
      tax        => $form->{"tax_$i"},
      project_id => ($i==$form->{rowcount}) ? $form->{globalproject_id} : $form->{"project_id_$i"},
    };

    my (%taxchart_labels, @taxchart_values, $default_taxchart, $taxchart_to_use);
    my $amount_chart_id = $form->{"AR_amount_chart_id_$i"} // $default_ar_amount_chart_id;

    my $used_tax_id;
    if ( $form->{"taxchart_$i"} ) {
      ($used_tax_id) = split(/--/, $form->{"taxchart_$i"});
    }
    foreach my $item ( GL->get_active_taxes_for_chart($amount_chart_id, $taxdate, $used_tax_id) ) {
      my $key             = $item->id . "--" . $item->rate;
      $first_taxchart   //= $item;
      $default_taxchart   = $item if $item->{is_default};
      $taxchart_to_use    = $item if $key eq $form->{"taxchart_$i"};

      push(@taxchart_values, $key);
      $taxchart_labels{$key} = $item->taxkey . " - " . $item->taxdescription . " " . $item->rate * 100 . ' %';
    }

    $taxchart_to_use    //= $default_taxchart // $first_taxchart;
    my $selected_taxchart = $taxchart_to_use->id . '--' . $taxchart_to_use->rate;

    $transaction->{selectAR_amount} =
        SL::Presenter::Chart::picker("AR_amount_chart_id_$i", $amount_chart_id, style => "width: 400px", type => "AR_amount", class => ($form->{initial_focus} eq "row_$i" ? "initial_focus" : ""))
      . SL::Presenter::Tag::hidden_tag("previous_AR_amount_chart_id_$i", $amount_chart_id);

    $transaction->{taxchart} =
      NTI($cgi->popup_menu('-name' => "taxchart_$i",
                           '-id' => "taxchart_$i",
                           '-style' => 'width:200px',
                           '-values' => \@taxchart_values,
                           '-labels' => \%taxchart_labels,
                           '-default' => $selected_taxchart));

    push @transactions, $transaction;
  }

  $form->{invtotal_unformatted} = $form->{invtotal};

  $form->{paidaccounts}++ if ($form->{"paid_$form->{paidaccounts}"});

  my $now = $form->current_date(\%myconfig);

  my @payments;

  # reset form value of defaultcurrency_totalpaid, as it is currently a hidden and otherwise it gets accumulated after each update
  # is only used if there are exchange rates
  $form->{"defaultcurrency_totalpaid"} = 0;

  for my $i (1 .. $form->{paidaccounts}) {
    # hook for calc of of defaultcurrency_paid and check if banktransaction has a record exchangerate
    if ($form->{"exchangerate_$i"} && $form->{"acc_trans_id_$i"}) {
      # only check for bank transactions for payments that have already been saved
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
      $form->{"defaultcurrency_totalpaid"} += $form->{"defaultcurrency_paid_$i"};
    } # end hook defaultcurrency_paid

    my $payment = {
      paid             => $form->{"paid_$i"},
      exchangerate     => $form->{"exchangerate_$i"} || '',
      gldate           => $form->{"gldate_$i"},
      acc_trans_id     => $form->{"acc_trans_id_$i"},
      source           => $form->{"source_$i"},
      memo             => $form->{"memo_$i"},
      AR_paid          => $form->{"AR_paid_$i"},
      forex            => $form->{"forex_$i"},
      record_forex     => $form->{"record_forex_$i"},
      datepaid         => $form->{"datepaid_$i"},
      paid_project_id  => $form->{"paid_project_id_$i"},
      gldate           => $form->{"gldate_$i"},
      # only used if we have an fx currency
      defaultcurrency_paid      => $form->{"defaultcurrency_paid_$i"},
      defaultcurrency_totalpaid => $form->{"defaultcurrency_totalpaid_$i"},
    };

    # default account for current assets (i.e. 1801 - SKR04) if no account is selected
    $form->{accno_arap} = IS->get_standard_accno_current_assets(\%myconfig, \%$form);

    $payment->{selectAR_paid} =
      NTI($cgi->popup_menu('-name' => "AR_paid_$i",
                           '-id' => "AR_paid_$i",
                           '-values' => \@AR_paid_values,
                           '-labels' => \%AR_paid_labels,
                           '-default' => $payment->{AR_paid} || $form->{accno_arap}));



    $payment->{changeable} =
        SL::DB::Default->get->payments_changeable == 0 ? !$payment->{acc_trans_id} # never
      : SL::DB::Default->get->payments_changeable == 2 ? $payment->{gldate} eq '' || $payment->{gldate} eq $now
      :                                                           1;

    #deaktivieren von gebuchten Zahlungen ausserhalb der Bücherkontrolle, vorher prüfen ob heute eingegeben
    if ($form->date_closed($payment->{"gldate_$i"})) {
        $payment->{changeable} = 0;
    }

    push @payments, $payment;
  }

  my @empty = grep { $_->{paid} eq '' } @payments;
  @payments = (
    (sort_by { DateTime->from_kivitendo($_->{datepaid}) } grep { $_->{paid} ne '' } @payments),
    @empty,
  );

  $form->{totalpaid} = sum map { $_->{paid} } @payments;

  my $employees = SL::DB::Manager::Employee->get_all_sorted(
    where => [
      or => [
        (id     => $::form->{employee_id}) x !!$::form->{employee_id},
        deleted => undef,
        deleted => 0,
      ],
    ],
  );

  setup_ar_form_header_action_bar();
  $::form->{paid_missing} =  $form->{is_linked_bank_transaction} && $form->{invoice_obj}->forex ?
                           $form->{invoice_obj}->open_amount
                        :  $::form->{invtotal} - $::form->{totalpaid};

  $form->header;
  print $::form->parse_html_template('ar/form_header', {
    paid_missing         => $::form->{paidmissing},
    show_exch            => ($::form->{defaultcurrency} && ($::form->{currency} ne $::form->{defaultcurrency})),
    payments             => \@payments,
    transactions         => \@transactions,
    project_labels       => \%project_labels,
    rows                 => $rows,
    AR_chart_id          => $form->{AR_chart_id},
    title_str            => $title,
    follow_up_trans_info => $follow_up_trans_info,
    today                => DateTime->today,
    currencies           => scalar(SL::DB::Manager::Currency->get_all_sorted),
    employees            => $employees,
  });

  $main::lxdebug->leave_sub();
}

sub form_footer {
  $main::lxdebug->enter_sub();

  _assert_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  if ( $form->{id} ) {
    my $follow_ups = FU->follow_ups('trans_id' => $form->{id}, 'not_done' => 1);
    if ( @{ $follow_ups} ) {
      $form->{follow_up_length} = scalar(@{$follow_ups});
      $form->{follow_up_due_length} = sum(map({ $_->{due} * 1 } @{ $follow_ups }));
    }
  }

  print $::form->parse_html_template('ar/form_footer');

  $main::lxdebug->leave_sub();
}

sub mark_as_paid {
  $::auth->assert('ar_transactions');

  SL::DB::Invoice->new(id => $::form->{id})->load->mark_as_paid;
  $::form->redirect($::locale->text("Marked as paid"));
}

sub show_draft {
  $::form->{transdate} = DateTime->today_local->to_kivitendo if !$::form->{transdate};
  $::form->{gldate}    = $::form->{transdate} if !$::form->{gldate};
  $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;
  update();
}

sub update {
  my %params = @_;
  $main::lxdebug->enter_sub();

  $main::auth->assert('ar_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my $display = shift;

  my ($totaltax, $exchangerate);

  $form->{invtotal} = 0;

  delete @{ $form }{ grep { m/^tax_\d+$/ } keys %{ $form } };

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(exchangerate creditlimit creditremaining);

  my @flds  = qw(amount AR_amount_chart_id projectnumber oldprojectnumber project_id taxchart tax);
  my $count = 0;
  my @a     = ();

  for my $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} = $form->parse_amount(\%myconfig, $form->{"amount_$i"});
    if ($form->{"amount_$i"} || $params{keep_rows_without_amount}) {
      push @a, {};
      my $j = $#a;
      my ($taxkey, $rate) = split(/--/, $form->{"taxchart_$i"});

      my $tmpnetamount;
      ($tmpnetamount,$form->{"tax_$i"}) = $form->calculate_tax($form->{"amount_$i"},$rate,$form->{taxincluded},2);

      $totaltax += $form->{"tax_$i"};
      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }

  $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});
  $form->{rowcount} = $count + ($params{dont_add_new_row} ? 0 : 1);
  map { $form->{invtotal} += $form->{"amount_$_"} } (1 .. $form->{rowcount});

  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{transdate}, 'buy');
  $form->{exchangerate} = $form->{forex} if $form->{forex};

  $form->{invdate} = $form->{transdate};

  if (($form->{previous_customer_id} || $form->{customer_id}) != $form->{customer_id}) {
    IS->get_customer(\%myconfig, $form);
    if (($form->{rowcount} == 1) && ($form->{amount_1} == 0)) {
      my $last_used_ar_chart = SL::DB::Customer->load_cached($form->{customer_id})->last_used_ar_chart;
      $form->{"AR_amount_chart_id_1"} = $last_used_ar_chart->id if $last_used_ar_chart;
    }
  }

  $form->{invtotal} =
    ($form->{taxincluded}) ? $form->{invtotal} : $form->{invtotal} + $totaltax;

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      map {
        $form->{"${_}_$i"} =
          $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
      } qw(paid exchangerate);

      $form->{totalpaid} += $form->{"paid_$i"};

      $form->{"forex_$i"}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy');
      $form->{"exchangerate_$i"} = $form->{"forex_$i"} if $form->{"forex_$i"};
    }
  }

  $form->{creditremaining} -=
    ($form->{invtotal} - $form->{totalpaid} + $form->{oldtotalpaid} -
     $form->{oldinvtotal});
  $form->{oldinvtotal}  = $form->{invtotal};
  $form->{oldtotalpaid} = $form->{totalpaid};

  display_form();

  $main::lxdebug->leave_sub();
}

#
# ToDO: fix $closedto and $invdate
#
sub post_payment {
  $main::lxdebug->enter_sub();

  $main::auth->assert('ar_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->mtime_ischanged('ar');
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
#        $form->{"exchangerate_$i"} = $form->{exchangerate} if ($invdate == $datepaid);
        $form->isblank("exchangerate_$i", $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  ($form->{AR})      = split /--/, $form->{AR};
  ($form->{AR_paid}) = split /--/, $form->{AR_paid};
  if (AR->post_payment(\%myconfig, \%$form)) {
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

sub _post {

  $main::auth->assert('ar_transactions');

  my $form     = $main::form;

  # inline post
  post(1);
}

sub post {
  $main::lxdebug->enter_sub();

  $main::auth->assert('ar_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my ($inline) = @_;

  $form->mtime_ischanged('ar');

  my ($datepaid);

  # check if there is an invoice number, invoice and due date
  $form->isblank("transdate", $locale->text('Invoice Date missing!'));
  $form->isblank("duedate",   $locale->text('Due Date missing!'));
  $form->isblank("customer_id", $locale->text('Customer missing!'));

  if ($myconfig{mandatory_departments} && !$form->{department_id}) {
    $form->{saved_message} = $::locale->text('You have to specify a department.');
    update();
    exit;
  }

  my $closedto  = $form->datetonum($form->{closedto},  \%myconfig);
  my $transdate = $form->datetonum($form->{transdate}, \%myconfig);

  $form->error($locale->text('Cannot post transaction above the maximum future booking date!'))
    if ($form->date_max_future($transdate, \%myconfig));

  $form->error($locale->text('Cannot post transaction for a closed period!')) if ($form->date_closed($form->{"transdate"}, \%myconfig));

  $form->error($locale->text('Zero amount posting!'))
    unless grep $_*1, map $form->parse_amount(\%myconfig, $form->{"amount_$_"}), 1..$form->{rowcount};

  if ($form->{defaultcurrency} && ($form->{currency} ne $form->{defaultcurrency})) {
    $form->isblank("exchangerate", $locale->text('Exchangerate missing!'));
    $form->error($locale->text('Cannot post invoice with negative exchange rate'))
      unless ($form->parse_amount(\%myconfig, $form->{"exchangerate"}) > 0);
  }

  delete($form->{AR});

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post transaction above the maximum future booking date!'))
        if ($form->date_max_future($form->{"datepaid_$i"}, \%myconfig));

      #Zusätzlich noch das Buchungsdatum in die Bücherkontrolle einbeziehen
      # (Dient zur Prüfung ob ZE oder ZA geprüft werden soll)
      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($form->date_closed($form->{"datepaid_$i"})  && !$form->date_closed($form->{"gldate_$i"}, \%myconfig));

      if ($form->{defaultcurrency} && ($form->{currency} ne $form->{defaultcurrency})) {
        $form->{"exchangerate_$i"} = $form->{exchangerate} if ($transdate == $datepaid);
        $form->isblank("exchangerate_$i", $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  # if oldcustomer ne customer redo form
  if (($form->{previous_customer_id} || $form->{customer_id}) != $form->{customer_id}) {
    update();
    $::dispatcher->end_request;
  }

  $form->{AR}{receivables} = $form->{ARselected};
  $form->{storno}          = 0;

  $form->error($locale->text('Cannot post transaction!')) unless AR->post_transaction(\%myconfig, \%$form);

  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers}  = "invnumber_$form->{invnumber}";
    $form->{what_done} = "invoice";
    $form->{addition}  = "POSTED";
    $form->save_history;
  }
  # /saving the history

  if ($form->{email_journal_id} && $form->{id} ne "") {
    my $ar_transaction = SL::DB::Invoice->new(id => $form->{id})->load;
    my $email_journal = SL::DB::EmailJournal->new(
      id => delete $form->{email_journal_id}
    )->load;
    $email_journal->link_to_record_with_attachment($ar_transaction, delete $::form->{email_attachment_id});
  }

  if (!$inline) {
    my $msg = $locale->text("AR transaction '#1' posted (ID: #2)", $form->{invnumber}, $form->{id});
    if ($::instance_conf->get_ar_add_doc && $::instance_conf->get_doc_storage) {
      my $add_doc_url = build_std_url("script=ar.pl", 'action=edit', 'id=' . E($form->{id}));
      SL::Helper::Flash::flash_later('info', $msg);
      print $form->redirect_header($add_doc_url);
      $::dispatcher->end_request;

    } else {
      $form->redirect($msg);
    }
  }

  $main::lxdebug->leave_sub();
}

sub post_and_close {
  $main::lxdebug->enter_sub();
  $main::auth->assert('ar_transactions');
  my $locale = $main::locale;
  my $form   = $::form;

  # inline post
  post(1);

  my $callback = $form->{callback}
    || "controller.pl?action=LoginScreen/user_login";
    my $msg = $locale->text("AR transaction '#1' posted (ID: #2)", $form->{invnumber}, $form->{id});
  SL::Helper::Flash::flash_later('info', $msg);
  print $form->redirect_header($callback);
  $::dispatcher->end_request;

  $main::lxdebug->leave_sub();
}

sub use_as_new {
  $main::lxdebug->enter_sub();

  $main::auth->assert('ar_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{email_journal_id}    = delete $form->{workflow_email_journal_id};
  $form->{email_attachment_id} = delete $form->{workflow_email_attachment_id};
  $form->{callback}            = delete $form->{workflow_email_callback};

  map { delete $form->{$_} } qw(printed emailed queued invnumber deliverydate id datepaid_1 gldate_1 acc_trans_id_1 source_1 memo_1 paid_1 exchangerate_1 AP_paid_1 storno);
  $form->{paidaccounts} = 1;
  $form->{rowcount}--;

  my $today          = DateTime->today_local;
  $form->{transdate} = $today->to_kivitendo;
  $form->{duedate}   = $form->{transdate};

  if ($form->{customer_id}) {
    my $payment_terms = SL::DB::Customer->load_cached($form->{customer_id})->payment;
    $form->{duedate}  = $payment_terms->calc_date(reference_date => $today)->to_kivitendo if $payment_terms;
  }

  $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;

  &update;

  $main::lxdebug->leave_sub();
}

sub delete {
  $::auth->assert('ar_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  if (AR->delete_transaction(\%myconfig, \%$form)) {
    # saving the history
    if(!exists $form->{addition}) {
      $form->{snumbers}  = qq|invnumber_| . $form->{invnumber};
      $form->{what_done} = "invoice";
      $form->{addition}  = "DELETED";
      $form->save_history;
    }
    # /saving the history
    $form->redirect($locale->text('Transaction deleted!'));
  }
  $form->error($locale->text('Cannot delete transaction!'));
}

sub setup_ar_search_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $::locale->text('Search'),
        submit    => [ '#form' ],
        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}

sub setup_ar_transactions_action_bar {
  my %params          = @_;
  my $may_edit_create = $::auth->assert('invoice_edit', 1);

  my $webdav_enabled = SL::DB::Default->get->webdav
                       && SL::DB::Default->get->webdav_documents;
  my $files_enabled  = SL::DB::Default->get->doc_storage;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $::locale->text('Print'),
        call     => [ 'kivi.MassInvoiceCreatePrint.showMassPrintOptionsOrDownloadDirectly' ],
        disabled => !$may_edit_create  ? t8('You do not have the permissions to access this function.')
                  : !$params{num_rows} ? $::locale->text('The report doesn\'t contain entries.')
                  :                      undef,
      ],
      combobox => [
        action => [ $::locale->text('PDF-Export') ],
        action => [
          t8('WebDAV'),
          submit   => [ '#report_form', { action => 'Invoice/webdav_pdf_export' } ],
          checks   => [ ['kivi.check_if_entries_selected', '[name="id[]"]'] ],
          disabled => !$webdav_enabled ? t8('WebDAV is not enabled.')
                                       : undef,
        ],
        action => [
          t8('Documents'),
          submit   => [ '#report_form', { action => 'Invoice/files_pdf_export' } ],
          checks   => [ ['kivi.check_if_entries_selected', '[name="id[]"]'] ],
          disabled => !$files_enabled ? t8('No File Management enabled.')
                                      : undef,
        ],
      ],
      combobox => [
        action => [ $::locale->text('Create new') ],
        action => [
          $::locale->text('AR Transaction'),
          submit   => [ '#create_new_form', { action => 'ar_transaction' } ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          $::locale->text('Sales Invoice'),
          submit   => [ '#create_new_form', { action => 'sales_invoice' } ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
      ], # end of combobox "Create new"
    );
  }
}

sub search {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  $form->{title} = $locale->text('Invoices, Credit Notes & AR Transactions');

  $form->{ALL_EMPLOYEES}      = SL::DB::Manager::Employee   ->get_all_sorted(query => [ deleted => 0 ]);
  $form->{ALL_DEPARTMENTS}    = SL::DB::Manager::Department ->get_all_sorted;
  $form->{ALL_BUSINESS_TYPES} = SL::DB::Manager::Business   ->get_all_sorted;
  $form->{ALL_TAXZONES}       = SL::DB::Manager::TaxZone    ->get_all_sorted;
  $form->{ALL_PAYMENT_TERMS}  = SL::DB::Manager::PaymentTerm->get_all_sorted;

  $form->{CT_CUSTOM_VARIABLES}                  = CVar->get_configs('module' => 'CT');
  ($form->{CT_CUSTOM_VARIABLES_FILTER_CODE},
   $form->{CT_CUSTOM_VARIABLES_INCLUSION_CODE}) = CVar->render_search_options('variables'      => $form->{CT_CUSTOM_VARIABLES},
                                                                              'include_prefix' => 'l_',
                                                                              'include_value'  => 'Y');

  # constants and subs for template
  $form->{vc_keys}   = sub { "$_[0]->{name}--$_[0]->{id}" };

  $::request->layout->add_javascripts("autocomplete_project.js");

  setup_ar_search_action_bar();

  $form->header;
  print $form->parse_html_template('ar/search', { %myconfig });

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

sub ar_transactions {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my ($callback, $href, @columns);

  my %params   = @_;
  report_generator_set_default_sort('transdate', 1);

  AR->ar_transactions(\%myconfig, \%$form);

  $form->{title} = $locale->text('Invoices, Credit Notes & AR Transactions');

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  @columns = qw(
    ids transdate id type invnumber ordnumber cusordnumber donumber
    deliverydate name netamount tax amount paid datepaid due duedate
    transaction_description notes salesman employee shippingpoint shipvia
    marge_total marge_percent globalprojectnumber customernumber country
    ustid taxzone payment_terms charts customertype direct_debit
    dunning_description department attachments items customer_dunning_lock
    shiptoname shiptodepartment_1 shiptodepartment_2 shiptostreet
    shiptozipcode shiptocity shiptocountry
  );

  my $ct_cvar_configs                 = CVar->get_configs('module' => 'CT');
  my @ct_includeable_custom_variables = grep { $_->{includeable} } @{ $ct_cvar_configs };
  my @ct_searchable_custom_variables  = grep { $_->{searchable} }  @{ $ct_cvar_configs };

  my %column_defs_cvars = map { +"cvar_$_->{name}" => { 'text' => $_->{description} } } @ct_includeable_custom_variables;
  push @columns, map { "cvar_$_->{name}" } @ct_includeable_custom_variables;

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, "l_subtotal", qw(
    open closed customer invnumber ordnumber cusordnumber
    transaction_description notes project_id transdatefrom transdateto
    duedatefrom duedateto datepaidfrom datepaidto employee_id salesman_id
    business_id parts_partnumber parts_description department_id
    show_marked_as_closed show_not_mailed shippingpoint shipvia taxzone_id
    payment_id shiptoname shiptodepartment_1 shiptodepartment_2 shiptostreet
    shiptozipcode shiptocity shiptocountry fulltext parts_serialnumber
  );
  push @hidden_variables, map { "cvar_$_->{name}" } @ct_searchable_custom_variables;

  $href =  $params{want_binary_pdf} ? '' : build_std_url('action=ar_transactions', grep { $form->{$_} } @hidden_variables);

  my %column_defs = (
    'ids'                     => { raw_header_data => SL::Presenter::Tag::checkbox_tag("", id => "check_all", checkall => "[data-checkall=1]"), align => 'center' },
    'transdate'               => { 'text' => $locale->text('Date'), },
    'id'                      => { 'text' => $locale->text('ID'), },
    'type'                    => { 'text' => $locale->text('Type'), },
    'invnumber'               => { 'text' => $locale->text('Invoice'), },
    'ordnumber'               => { 'text' => $locale->text('Order'), },
    'cusordnumber'            => { 'text' => $locale->text('Customer Order Number'), },
    'donumber'                => { 'text' => $locale->text('Delivery Order'), },
    'deliverydate'            => { 'text' => $locale->text('Delivery Date'), },
    'name'                    => { 'text' => $locale->text('Customer'), },
    'netamount'               => { 'text' => $locale->text('Amount'), },
    'tax'                     => { 'text' => $locale->text('Tax'), },
    'amount'                  => { 'text' => $locale->text('Total'), },
    'paid'                    => { 'text' => $locale->text('Paid'), },
    'datepaid'                => { 'text' => $locale->text('Date Paid'), },
    'due'                     => { 'text' => $locale->text('Amount Due'), },
    'duedate'                 => { 'text' => $locale->text('Due Date'), },
    'transaction_description' => { 'text' => $locale->text('Transaction description'), },
    'notes'                   => { 'text' => $locale->text('Notes'), },
    'salesman'                => { 'text' => $locale->text('Salesperson'), },
    'employee'                => { 'text' => $locale->text('Employee'), },
    'shippingpoint'           => { 'text' => $locale->text('Shipping Point'), },
    'shipvia'                 => { 'text' => $locale->text('Ship via'), },
    'globalprojectnumber'     => { 'text' => $locale->text('Document Project Number'), },
    'marge_total'             => { 'text' => $locale->text('Ertrag'), },
    'marge_percent'           => { 'text' => $locale->text('Ertrag prozentual'), },
    'customernumber'          => { 'text' => $locale->text('Customer Number'), },
    'country'                 => { 'text' => $locale->text('Country'), },
    'ustid'                   => { 'text' => $locale->text('USt-IdNr.'), },
    'taxzone'                 => { 'text' => $locale->text('Steuersatz'), },
    'payment_terms'           => { 'text' => $locale->text('Payment Terms'), },
    'charts'                  => { 'text' => $locale->text('Chart'), },
    'customertype'            => { 'text' => $locale->text('Customer type'), },
    'direct_debit'            => { 'text' => $locale->text('direct debit'), },
    'department'              => { 'text' => $locale->text('Department'), },
    dunning_description       => { 'text' => $locale->text('Dunning level'), },
    attachments               => { 'text' => $locale->text('Attachments'), },
    items                     => { 'text' => $locale->text('Positions'), },
    customer_dunning_lock     => { 'text' => $locale->text('Dunning lock'), },
    shiptoname                => { 'text' => $locale->text('Name (Shipping)'), },
    shiptodepartment_1        => { 'text' => $locale->text('Department 1 (Shipping)'), },
    shiptodepartment_2        => { 'text' => $locale->text('Department 2 (Shipping)'), },
    shiptostreet              => { 'text' => $locale->text('Street (Shipping)'), },
    shiptozipcode             => { 'text' => $locale->text('Zipcode (Shipping)'), },
    shiptocity                => { 'text' => $locale->text('City (Shipping)'), },
    shiptocountry             => { 'text' => $locale->text('Country (Shipping)'), },
    %column_defs_cvars,
  );

  foreach my $name (qw(id transdate duedate invnumber ordnumber cusordnumber donumber deliverydate name datepaid employee shippingpoint shipvia transaction_description direct_debit department taxzone)) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=$name&sortdir=$sortdir";
  }

  my %column_alignment = map { $_ => 'right' } qw(netamount tax amount paid due);

  $form->{"l_type"} = "Y";
  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;

  $column_defs{ids}->{visible} = 'HTML';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('ar_transactions', @hidden_variables, qw(sort sortdir));

  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  CVar->add_custom_variables_to_report('module'         => 'CT',
                                       'trans_id_field' => 'customer_id',
                                       'configs'        => $ct_cvar_configs,
                                       'column_defs'    => \%column_defs,
                                       'data'           => $form->{AR});

  my @options;
  if ($form->{customer}) {
    push @options, $locale->text('Customer') . " : $form->{customer}";
  }
  if ($form->{cp_name}) {
    push @options, $locale->text('Contact Person') . " : $form->{cp_name}";
  }

  if ($form->{department_id}) {
    my $department = SL::DB::Manager::Department->find_by( id => $form->{department_id} );
    push @options, $locale->text('Department') . " : " . $department->description;
  }
  if ($form->{invnumber}) {
    push @options, $locale->text('Invoice Number') . " : $form->{invnumber}";
  }
  if ($form->{ordnumber}) {
    push @options, $locale->text('Order Number') . " : $form->{ordnumber}";
  }
  if ($form->{cusordnumber}) {
    push @options, $locale->text('Customer Order Number') . " : $form->{cusordnumber}";
  }
  if ($form->{notes}) {
    push @options, $locale->text('Notes') . " : $form->{notes}";
  }
  if ($form->{transaction_description}) {
    push @options, $locale->text('Transaction description') . " : $form->{transaction_description}";
  }
  if ($form->{payment_id}) {
    my $payment_term = SL::DB::Manager::PaymentTerm->find_by( id => $form->{payment_id} );
    push @options, $locale->text('Payment Term') . " : " . $payment_term->description;
  }
  if ($form->{parts_partnumber}) {
    push @options, $locale->text('Part Number') . " : $form->{parts_partnumber}";
  }
  if ($form->{parts_description}) {
    push @options, $locale->text('Part Description') . " : $form->{parts_description}";
  }
  if ($form->{transdatefrom}) {
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{transdatefrom}, 1);
  }
  if ($form->{transdateto}) {
    push @options, $locale->text('Bis') . " " . $locale->date(\%myconfig, $form->{transdateto}, 1);
  }
  if ($form->{duedatefrom}) {
    push @options, $locale->text('Due Date') . " " . $locale->text('from') . " " . $locale->date(\%myconfig, $form->{duedatefrom}, 1);
  }
  if ($form->{duedateto}) {
    push @options, $locale->text('Due Date') . " " . $locale->text('to') . " " . $locale->date(\%myconfig, $form->{duedateto}, 1);
  }
  if ($form->{datepaidfrom}) {
    push @options, $locale->text('Date Paid') . " " . $locale->text('from') . " " . $locale->date(\%myconfig, $form->{datepaidfrom}, 1);
  }
  if ($form->{datepaidto}) {
    push @options, $locale->text('Date Paid') . " " . $locale->text('to') . " " . $locale->date(\%myconfig, $form->{datepaidto}, 1);
  }
  if ($form->{open}) {
    push @options, $locale->text('Open');
  }
  if ($form->{employee_id}) {
    my $employee = SL::DB::Employee->new(id => $form->{employee_id})->load;
    push @options, $locale->text('Employee') . ' : ' . $employee->name;
  }
  if ($form->{salesman_id}) {
    my $salesman = SL::DB::Employee->new(id => $form->{salesman_id})->load;
    push @options, $locale->text('Salesman') . ' : ' . $salesman->name;
  }
  if ($form->{closed}) {
    push @options, $locale->text('Closed');
  }
  if ($form->{shipvia}) {
    push @options, $locale->text('Ship via') . " : $form->{shipvia}";
  }
  if ($form->{shippingpoint}) {
    push @options, $locale->text('Shipping Point') . " : $form->{shippingpoint}";
  }
  if ($form->{shiptoname}) {
    push @options, $locale->text('Name (Shipping)') . " : $form->{shiptoname}";
  }
  if ($form->{shiptodepartment_1}) {
    push @options, $locale->text('Department 1 (Shipping)') . " : $form->{shiptodepartment_1}";
  }
  if ($form->{shiptodepartment_2}) {
    push @options, $locale->text('Department 2 (Shipping)') . " : $form->{shiptodepartment_2}";
  }
  if ($form->{shiptostreet}) {
    push @options, $locale->text('Street (Shipping)') . " : $form->{shiptostreet}";
  }
  if ($form->{shiptozipcode}) {
    push @options, $locale->text('Zipcode (Shipping)') . " : $form->{shiptozipcode}";
  }
  if ($form->{shiptocity}) {
    push @options, $locale->text('City (Shipping)') . " : $form->{shiptocity}";
  }
  if ($form->{shiptocountry}) {
    push @options, $locale->text('Country (Shipping)') . " : $form->{shiptocountry}";
  }
  if ($form->{fulltext}) {
    push @options, $locale->text('Full Text') . " : $form->{fulltext}";
  }
  if ($form->{parts_serialnumber}) {
    push @options, $locale->text('Serial Number') . " : $form->{parts_serialnumber}";
  }

  $form->{ALL_PRINTERS} = SL::DB::Manager::Printer->get_all_sorted;

  $report->set_options('top_info_text'        => join("\n", @options),
                       'raw_top_info_text'    => $form->parse_html_template('ar/ar_transactions_header'),
                       'raw_bottom_info_text' => $form->parse_html_template('ar/ar_transactions_bottom'),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $locale->text('invoice_list') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $href .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($href);

  my @subtotal_columns = qw(netamount amount paid due marge_total marge_percent);

  my %totals    = map { $_ => 0 } @subtotal_columns;
  my %subtotals = map { $_ => 0 } @subtotal_columns;

  my $idx = 0;

  foreach my $ar (@{ $form->{AR} }) {
    $ar->{tax} = $ar->{amount} - $ar->{netamount};
    $ar->{due} = $ar->{amount} - $ar->{paid};

    map { $subtotals{$_} += $ar->{$_};
          $totals{$_}    += $ar->{$_} } @subtotal_columns;

    $subtotals{marge_percent} = $subtotals{netamount} ? ($subtotals{marge_total} * 100 / $subtotals{netamount}) : 0;
    $totals{marge_percent}    = $totals{netamount}    ? ($totals{marge_total}    * 100 / $totals{netamount}   ) : 0;

    # Preserve $ar->{type} before changing it to the abbreviation letter for
    # getting files from file management below.
    $ar->{object_type} = $ar->{type};

    my $is_storno  = $ar->{storno} &&  $ar->{storno_id};
    my $has_storno = $ar->{storno} && !$ar->{storno_id};

    if ($ar->{type} eq 'invoice_for_advance_payment') {
      $ar->{type} =
        $has_storno       ? $locale->text("Invoice for Advance Payment with Storno (abbreviation)") :
        $is_storno        ? $locale->text("Storno (one letter abbreviation)") :
                            $locale->text("Invoice for Advance Payment (one letter abbreviation)");

    } elsif ($ar->{type} eq 'final_invoice') {
      $ar->{type} = t8('Final Invoice (one letter abbreviation)');

    } else {
      $ar->{type} =
        $has_storno       ? $locale->text("Invoice with Storno (abbreviation)") :
        $is_storno        ? $locale->text("Storno (one letter abbreviation)") :
        $ar->{amount} < 0 ? $locale->text("Credit note (one letter abbreviation)") :
        $ar->{invoice}    ? $locale->text("Invoice (one letter abbreviation)") :
                            $locale->text("AR Transaction (abbreviation)");
    }

    map { $ar->{$_} = $form->format_amount(\%myconfig, $ar->{$_}, 2) } qw(netamount tax amount paid due marge_total marge_percent);

    $ar->{direct_debit} = $ar->{direct_debit} ? $::locale->text('yes') : $::locale->text('no');

    my $row = { };

    foreach my $column (@columns) {
      next if ($column eq 'items');

      $row->{$column} = {
        'data'  => $ar->{$column},
        'align' => $column_alignment{$column},
      };
    }

    $row->{invnumber}->{link} = build_std_url("script=" . ($ar->{invoice} ? 'is.pl' : 'ar.pl'), 'action=edit')
      . "&id=" . E($ar->{id}) . "&callback=${callback}" unless $params{want_binary_pdf};

    $row->{ids} = {
      raw_data =>  SL::Presenter::Tag::checkbox_tag("id[]", value => $ar->{id}, "data-checkall" => 1),
      valign   => 'center',
      align    => 'center',
    };

    if ($::instance_conf->get_doc_storage && $form->{l_attachments}) {
      my @files  = SL::File->get_all_versions(object_id   => $ar->{id},
                                              object_type => $ar->{object_type} || 'invoice',
                                              file_type   => 'attachment',);
      if (scalar @files) {
        my $html            = join '<br>', map { SL::Presenter::FileObject::file_object($_) } @files;
        my $text            = join "\n",   map { $_->file_name                              } @files;
        $row->{attachments} = { 'raw_data' => $html, data => $text };
      } else {
        $row->{attachments} = { };
      }

    }

    if ($form->{l_items}) {
      my $items = SL::DB::Manager::InvoiceItem->get_all_sorted(where => [id => $ar->{item_ids}]);
      $row->{items}->{raw_data}  = SL::Presenter::ItemsList::items_list($items)               if lc($report->{options}->{output_format}) eq 'html';
      $row->{items}->{data}      = SL::Presenter::ItemsList::items_list($items, as_text => 1) if lc($report->{options}->{output_format}) ne 'html';
    }

    my $row_set = [ $row ];

    if (($form->{l_subtotal} eq 'Y')
        && (($idx == (scalar @{ $form->{AR} } - 1))
            || ($ar->{ $form->{sort} } ne $form->{AR}->[$idx + 1]->{ $form->{sort} }))) {
      push @{ $row_set }, create_subtotal_row(\%subtotals, \@columns, \%column_alignment, \@subtotal_columns, 'listsubtotal');
    }

    $report->add_data($row_set);

    $idx++;
  }

  $report->add_separator();
  $report->add_data(create_subtotal_row(\%totals, \@columns, \%column_alignment, \@subtotal_columns, 'listtotal'));

  if ($params{want_binary_pdf}) {
    $report->generate_with_headers();
    return $report->generate_pdf_content(want_binary_pdf => 1);
  }

  $::request->layout->add_javascripts('kivi.MassInvoiceCreatePrint.js');
  setup_ar_transactions_action_bar(num_rows => scalar(@{ $form->{AR} }));

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub storno {
  $main::lxdebug->enter_sub();

  $main::auth->assert('ar_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  # don't cancel cancelled transactions
  if (IS->has_storno(\%myconfig, $form, 'ar')) {
    $form->{title} = $locale->text("Cancel Accounts Receivables Transaction");
    $form->error($locale->text("Transaction has already been cancelled!"));
  }

  AR->storno($form, \%myconfig, $form->{id});

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

sub setup_ar_form_header_action_bar {
  my $transdate               = $::form->datetonum($::form->{transdate}, \%::myconfig);
  my $closedto                = $::form->datetonum($::form->{closedto},  \%::myconfig);
  my $is_closed               = $transdate <= $closedto;

  my $change_never            = $::instance_conf->get_ar_changeable == 0;
  my $change_on_same_day_only = $::instance_conf->get_ar_changeable == 2 && ($::form->current_date(\%::myconfig) ne $::form->{gldate});

  my $is_storno               = IS->is_storno(\%::myconfig, $::form, 'ar', $::form->{id});
  my $has_storno              = IS->has_storno(\%::myconfig, $::form, 'ar');
  my $may_edit_create         = $::auth->assert('ar_transactions', 1);

  my $is_linked_bank_transaction;
  if ($::form->{id}
      && SL::DB::Manager::BankTransactionAccTrans->find_by(ar_id => $::form->{id})) {

    $is_linked_bank_transaction = 1;
  }
  # add readonly state in $::form
  $::form->{readonly} = !$may_edit_create                           ? 1
                      : $is_closed                                  ? 1
                      : $is_storno                                  ? 1
                      : $has_storno                                 ? 1
                      : ($::form->{id} && $change_never)            ? 1
                      : ($::form->{id} && $change_on_same_day_only) ? 1
                      : $is_linked_bank_transaction                 ? 1
                      : 0;
  # and is_linked_bank_transaction
  $::form->{is_linked_bank_transaction} = $is_linked_bank_transaction;
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => "update" } ],
        id        => 'update_button',
        checks    => [ 'kivi.validate_form' ],
        disabled  => !$may_edit_create ? t8('You must not change this AR transaction.') : undef,
        accesskey => 'enter',
      ],

      combobox => [
        action => [
          t8('Post'),
          submit   => [ '#form', { action => "post" } ],
          checks   => [ 'kivi.validate_form', 'kivi.AR.check_fields_before_posting' ],
          disabled => !$may_edit_create                           ? t8('You must not change this AR transaction.')
                    : $is_closed                                  ? t8('The billing period has already been locked.')
                    : $is_storno                                  ? t8('A canceled invoice cannot be posted.')
                    : ($::form->{id} && $change_never)            ? t8('Changing invoices has been disabled in the configuration.')
                    : ($::form->{id} && $change_on_same_day_only) ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction                 ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                                               undef,
        ],
        action => [
          t8('Post and Close'),
          submit   => [ '#form', { action => "post_and_close" } ],
          checks   => [ 'kivi.validate_form', 'kivi.AR.check_fields_before_posting' ],
          disabled => !$may_edit_create                           ? t8('You must not change this AR transaction.')
                    : $is_closed                                  ? t8('The billing period has already been locked.')
                    : $is_storno                                  ? t8('A canceled invoice cannot be posted.')
                    : ($::form->{id} && $change_never)            ? t8('Changing invoices has been disabled in the configuration.')
                    : ($::form->{id} && $change_on_same_day_only) ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction                 ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                                               undef,
        ],
        action => [
          t8('Post Payment'),
          submit   => [ '#form', { action => "post_payment" } ],
          disabled => !$may_edit_create           ? t8('You must not change this AR transaction.')
                    : !$::form->{id}              ? t8('This invoice has not been posted yet.')
                    : $is_linked_bank_transaction ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                               undef,
        ],
        action => [ t8('Mark as paid'),
          submit   => [ '#form', { action => "mark_as_paid" } ],
          confirm  => t8('This will remove the invoice from showing as unpaid even if the unpaid amount does not match the amount. Proceed?'),
          disabled => !$may_edit_create ? t8('You must not change this AR transaction.')
                    : !$::form->{id}    ? t8('This invoice has not been posted yet.')
                    :                     undef,
          only_if  => $::instance_conf->get_is_show_mark_as_paid,
        ],
      ], # end of combobox "Post"

      combobox => [
        action => [ t8('Storno'),
          submit   => [ '#form', { action => "storno" } ],
          checks   => [ 'kivi.validate_form', 'kivi.AR.check_fields_before_posting' ],
          confirm  => t8('Do you really want to cancel this invoice?'),
          disabled => !$may_edit_create    ? t8('You must not change this AR transaction.')
                    : !$::form->{id}       ? t8('This invoice has not been posted yet.')
                    : $has_storno          ? t8('This invoice has been canceled already.')
                    : $is_storno           ? t8('Reversal invoices cannot be canceled.')
                    : $::form->{totalpaid} ? t8('Invoices with payments cannot be canceled.')
                    :                        undef,
        ],
        action => [ t8('Delete'),
          submit   => [ '#form', { action => "delete" } ],
          confirm  => t8('Do you really want to delete this object?'),
          disabled => !$may_edit_create        ? t8('You must not change this AR transaction.')
                    : !$::form->{id}           ? t8('This invoice has not been posted yet.')
                    : $change_never            ? t8('Changing invoices has been disabled in the configuration.')
                    : $change_on_same_day_only ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_closed               ? t8('The billing period has already been locked.')
                    :                            undef,
        ],
      ], # end of combobox "Storno"

      'separator',

      combobox => [
        action => [ t8('Workflow') ],
        action => [
          t8('Use As New'),
          submit   => [ '#form', { action => "use_as_new" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create ? t8('You must not change this AR transaction.')
                    : !$::form->{id} ? t8('This invoice has not been posted yet.')
                    :                  undef,
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
          call     => [ 'kivi.RecordTemplate.popup', 'ar_transaction' ],
          disabled => !$may_edit_create ? t8('You must not change this AR transaction.') : undef,
        ],
        action => [
          t8('Drafts'),
          call     => [ 'kivi.Draft.popup', 'ar', 'invoice', $::form->{draft_id}, $::form->{draft_description} ],
          disabled => !$may_edit_create ? t8('You must not change this AR transaction.')
                    : $::form->{id}     ? t8('This invoice has already been posted.')
                    : $is_closed        ? t8('The billing period has already been locked.')
                    :                     undef,
        ],
      ], # end of combobox "more"
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}

1;
