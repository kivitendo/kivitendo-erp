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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
#
# Inventory invoicing module
#
#======================================================================

use SL::FU;
use SL::IS;
use SL::OE;
use SL::Helper::UserPreferences::DisplayPreferences;
use SL::MoreCommon qw(restore_form save_form);
use SL::RecordLinks;

use Data::Dumper;
use DateTime;
use List::MoreUtils qw(any uniq);
use List::Util qw(max sum);
use List::UtilsBy qw(sort_by);
use English qw(-no_match_vars);

use SL::DB::BankTransactionAccTrans;
use SL::DB::Default;
use SL::DB::Chart;
use SL::DB::Customer;
use SL::DB::Department;
use SL::DB::Invoice;
use SL::DB::PaymentTerm;
use SL::DB::Reclamation;
use SL::DB::EmailJournal;
use SL::DB::ValidityToken;
use SL::Helper::QrBillFunctions qw(get_ref_number_formatted);

require "bin/mozilla/common.pl";
require "bin/mozilla/io.pl";

use strict;

1;

# end of main

sub _may_view_or_edit_this_invoice {
  return 1 if  $::auth->assert('invoice_edit', 1);       # may edit all invoices
  return 0 if !$::form->{id};                            # creating new invoices isn't allowed without invoice_edit
  return 1 if  $::auth->assert('sales_invoice_view', 1); # viewing is allowed with this right
  return 0 if !$::form->{globalproject_id};              # existing records without a project ID are not allowed
  return SL::DB::Project->new(id => $::form->{globalproject_id})->load->may_employee_view_project_invoices(SL::DB::Manager::Employee->current);
}

sub _assert_access {
  my $cache = $::request->cache('is.pl::_assert_access');

  $cache->{_may_view_or_edit_this_invoice} = _may_view_or_edit_this_invoice()                              if !exists $cache->{_may_view_or_edit_this_invoice};
  $::form->show_generic_error($::locale->text("You do not have the permissions to access this function.")) if !       $cache->{_may_view_or_edit_this_invoice};
}

sub add {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');

  $form->{show_details} = $::myconfig{show_form_details};

  if ($form->{type} eq "credit_note") {
    $form->{title} = $locale->text('Add Credit Note');

    if ($form->{storno}) {
      $form->{title} = $locale->text('Add Storno Credit Note');
    }

  } elsif ($form->{type} eq "invoice_for_advance_payment") {
    $form->{title} = $locale->text('Add Invoice for Advance Payment');

  } elsif ($form->{type} eq "final_invoice") {
    $form->{title} = $locale->text('Add Final Invoice');

  } else {
    $form->{title} = $locale->text('Add Sales Invoice');

  }

  if (!$form->{form_validity_token}) {
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;
  }

  $form->{callback} = "$form->{script}?action=add&type=$form->{type}" unless $form->{callback};

  invoice_links(is_new => 1);
  &prepare_invoice;
  &display_form;

  $main::lxdebug->leave_sub();
}

sub add_from_email_journal {
  die "No 'email_journal_id' was given." unless ($::form->{email_journal_id});
  &add;
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
  # "invoice_links" so that project-specific invoice rights can be
  # evaluated.

  my $form     = $main::form;
  my $locale   = $main::locale;

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

  } elsif ($form->{type} eq "invoice_for_advance_payment") {
    $form->{title} = $locale->text('Edit Invoice for Advance Payment');
    $form->{title} = $locale->text('Edit Storno Invoice for Advance Payment') if $form->{storno};

  } elsif ($form->{type} eq "final_invoice") {
    $form->{title} = $locale->text('Edit Final Invoice');

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

  # Delay access check to after the invoice's been loaded so that
  # project-specific invoice rights can be evaluated.

  my %params   = @_;
  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{vc} = 'customer';

  # create links
  $form->create_links("AR", \%myconfig, "customer");

  my $transfer_chart_id = $::instance_conf->get_advance_payment_clearing_chart_id;
  if ($transfer_chart_id) {
    # remove transfer chart for select box AR
    @{ $form->{AR_links}{AR} } =  grep { $_->{chart_id} != $transfer_chart_id } @{ $form->{AR_links}{AR} };
  }

  _assert_access();

  my $editing = $form->{id};

  $form->backup_vars(qw(payment_id language_id taxzone_id salesman_id
                        taxincluded currency cp_id intnotes id shipto_id
                        delivery_term_id));

  IS->get_customer(\%myconfig, \%$form);

  $form->{billing_address_id} = $form->{default_billing_address_id} if $params{is_new};

  $form->restore_vars(qw(id));

  IS->retrieve_invoice(\%myconfig, \%$form);
  $form->restore_vars(qw(payment_id language_id taxzone_id currency intnotes
                         cp_id shipto_id delivery_term_id));
  $form->restore_vars(qw(taxincluded)) if $form->{id};
  $form->restore_vars(qw(salesman_id)) if $editing;

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
        $form->{"defaultcurrency_paid_$i"} = $form->{acc_trans}{$key}->[$i - 1]->{defaultcurrency_paid};
        $form->{"fx_transaction_$i"}  = $form->{acc_trans}{$key}->[$i - 1]->{fx_transaction};


        $form->{paidaccounts} = $i;
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

      }
    } else {
      $form->{$key} = "$form->{acc_trans}{$key}->[0]->{accno}--$form->{acc_trans}{$key}->[0]->{description}";
    }
  }

  $form->{paidaccounts} = 1 unless (exists $form->{paidaccounts});

  my ($chart_accno) = split /--/, $form->{AR}; # is empty if total is 0
  $form->{AR_chart_id} = $form->{id} && $chart_accno ? SL::DB::Manager::Chart->find_by(accno => $chart_accno)->id
                       : $form->{AR_chart_id}        ? $form->{AR_chart_id}
                       : $::instance_conf->get_ar_chart_id;

  $form->{locked} = ($form->datetonum($form->{invdate},  \%myconfig)
                  <= $form->datetonum($form->{closedto}, \%myconfig));

  $main::lxdebug->leave_sub();
}

sub prepare_invoice {
  $main::lxdebug->enter_sub();

  _assert_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  if ($form->{type} eq "credit_note") {
    $form->{type}     = "credit_note";
    $form->{formname} = "credit_note";

  } elsif ($form->{type} eq "invoice_for_advance_payment") {
    $form->{type}     = "invoice_for_advance_payment";
    $form->{formname} = "invoice_for_advance_payment";

  } elsif ($form->{type} eq "final_invoice") {
    $form->{type}     = "final_invoice";
    $form->{formname} = "final_invoice";

  } elsif ($form->{formname} eq "proforma" ) {
    $form->{type}     = "invoice";

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

sub setup_is_action_bar {
  my ($tmpl_var)              = @_;
  my $form                    = $::form;
  my $change_never            = $::instance_conf->get_is_changeable == 0;
  my $change_on_same_day_only = $::instance_conf->get_is_changeable == 2 && ($form->current_date(\%::myconfig) ne $form->{gldate});
  my $payments_balanced       = ($::form->{oldtotalpaid} == 0);
  my $has_storno              = ($::form->{storno} && !$::form->{storno_id});
  my $may_edit_create         = $::auth->assert('invoice_edit', 1);
  my $factur_x_enabled        = $tmpl_var->{invoice_obj} && $tmpl_var->{invoice_obj}->customer->create_zugferd_invoices_for_this_customer;
  my ($is_linked_bank_transaction, $warn_unlinked_delivery_order);
    if ($::form->{id}
        && SL::DB::Default->get->payments_changeable != 0
        && SL::DB::Manager::BankTransactionAccTrans->find_by(ar_id => $::form->{id})) {

      $is_linked_bank_transaction = 1;
    }
  if ($::instance_conf->get_warn_no_delivery_order_for_invoice && !$form->{id}) {
    $warn_unlinked_delivery_order = 1 unless $form->{convert_from_do_ids};
  }

  my $has_further_invoice_for_advance_payment;
  if ($form->{id} && $form->{type} eq "invoice_for_advance_payment") {
    my $invoice_obj = SL::DB::Invoice->load_cached($form->{id});
    my $lr          = $invoice_obj->linked_records(direction => 'to', to => ['Invoice']);
    $has_further_invoice_for_advance_payment = any {'SL::DB::Invoice' eq ref $_ && "invoice_for_advance_payment" eq $_->type} @$lr;
  }

  my $has_final_invoice;
  if ($form->{id} && $form->{type} eq "invoice_for_advance_payment") {
    my $invoice_obj = SL::DB::Invoice->load_cached($form->{id});
    my $lr          = $invoice_obj->linked_records(direction => 'to', to => ['Invoice']);
    $has_final_invoice = any {'SL::DB::Invoice' eq ref $_ && "final_invoice" eq $_->invoice_type} @$lr;
  }

  my $is_invoice_for_advance_payment_from_order;
  if ($form->{id} && $form->{type} eq "invoice_for_advance_payment") {
    my $invoice_obj = SL::DB::Invoice->load_cached($form->{id});
    my $lr          = $invoice_obj->linked_records(direction => 'from', from => ['Order']);
    $is_invoice_for_advance_payment_from_order = scalar @$lr >= 1;
  }
  # add readonly state in tmpl_vars
  $tmpl_var->{readonly} = !$may_edit_create                     ? 1
                    : $form->{locked}                           ? 1
                    : $form->{storno}                           ? 1
                    : ($form->{id} && $change_never)            ? 1
                    : ($form->{id} && $change_on_same_day_only) ? 1
                    : $is_linked_bank_transaction               ? 1
                    : 0;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => "update" } ],
        disabled  => !$may_edit_create ? t8('You must not change this invoice.')
                   : $form->{locked}   ? t8('The billing period has already been locked.')
                   :                     undef,
        id        => 'update_button',
        accesskey => 'enter',
      ],

      combobox => [
        action => [
          t8('Post'),
          submit   => [ '#form', { action => "post" } ],
          checks   => [ 'kivi.validate_form' ],
          confirm  => t8('The invoice is not linked with a sales delivery order. Post anyway?') x !!$warn_unlinked_delivery_order,
          disabled => !$may_edit_create                         ? t8('You must not change this invoice.')
                    : $form->{locked}                           ? t8('The billing period has already been locked.')
                    : $form->{storno}                           ? t8('A canceled invoice cannot be posted.')
                    : ($form->{id} && $change_never)            ? t8('Changing invoices has been disabled in the configuration.')
                    : ($form->{id} && $change_on_same_day_only) ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction               ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                                             undef,
        ],
        action => [
          t8('Post and Close'),
          submit   => [ '#form', { action => "post_and_close" } ],
          checks   => [ 'kivi.validate_form' ],
          confirm  => t8('The invoice is not linked with a sales delivery order. Post anyway?') x !!$warn_unlinked_delivery_order,
          disabled => !$may_edit_create                         ? t8('You must not change this invoice.')
                    : $form->{locked}                           ? t8('The billing period has already been locked.')
                    : $form->{storno}                           ? t8('A canceled invoice cannot be posted.')
                    : ($form->{id} && $change_never)            ? t8('Changing invoices has been disabled in the configuration.')
                    : ($form->{id} && $change_on_same_day_only) ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction               ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                                             undef,
        ],
        action => [
          t8('Post Payment'),
          submit   => [ '#form', { action => "post_payment" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create           ? t8('You must not change this invoice.')
                    : !$form->{id}                ? t8('This invoice has not been posted yet.')
                    : $is_linked_bank_transaction ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                               undef,
          only_if  => $form->{type} ne "invoice_for_advance_payment",
        ],
        action => [ t8('Mark as paid'),
          submit   => [ '#form', { action => "mark_as_paid" } ],
          confirm  => t8('This will remove the invoice from showing as unpaid even if the unpaid amount does not match the amount. Proceed?'),
          disabled => !$may_edit_create ? t8('You must not change this invoice.')
                    : !$form->{id}      ? t8('This invoice has not been posted yet.')
                    :                     undef,
          only_if  => ($::instance_conf->get_is_show_mark_as_paid && $form->{type} ne "invoice_for_advance_payment") || $form->{type} eq 'final_invoice',
        ],
      ], # end of combobox "Post"

      combobox => [
        action => [ t8('Storno'),
          submit   => [ '#form', { action => "storno" } ],
          confirm  => t8('Do you really want to cancel this invoice?'),
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create   ? t8('You must not change this invoice.')
                    : !$form->{id}        ? t8('This invoice has not been posted yet.')
                    : $form->{storno}     ? t8('Cannot storno storno invoice!')
                    : $form->{locked}     ? t8('The billing period has already been locked.')
                    : !$payments_balanced ? t8('Cancelling is disallowed. Either undo or balance the current payments until the open amount matches the invoice amount')
                    : undef,
        ],
        action => [ t8('Delete'),
          submit   => [ '#form', { action => "delete" } ],
          confirm  => t8('Do you really want to delete this object?'),
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create        ? t8('You must not change this invoice.')
                    : !$form->{id}             ? t8('This invoice has not been posted yet.')
                    : $form->{locked}          ? t8('The billing period has already been locked.')
                    : $change_never            ? t8('Changing invoices has been disabled in the configuration.')
                    : $change_on_same_day_only ? t8('Invoices can only be changed on the day they are posted.')
                    : $has_storno              ? t8('Can only delete the "Storno zu" part of the cancellation pair.')
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
          disabled => !$may_edit_create ? t8('You must not change this invoice.')
                    : !$form->{id}      ? t8('This invoice has not been posted yet.')
                    :                     undef,
        ],
        action => [
          t8('Further Invoice for Advance Payment'),
          submit   => [ '#form', { action => "further_invoice_for_advance_payment" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create                          ? t8('You must not change this invoice.')
                    : !$form->{id}                               ? t8('This invoice has not been posted yet.')
                    : $has_further_invoice_for_advance_payment   ? t8('This invoice has already a further invoice for advanced payment.')
                    : $has_final_invoice                         ? t8('This invoice has already a final invoice.')
                    : $is_invoice_for_advance_payment_from_order ? t8('This invoice was added from an order. See there.')
                    :                                              undef,
          only_if  => ($form->{type} eq "invoice_for_advance_payment" && $::instance_conf->get_show_invoice_for_advance_payment),
        ],
        action => [
          t8('Final Invoice'),
          submit   => [ '#form', { action => "final_invoice" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create                          ? t8('You must not change this invoice.')
                    : !$form->{id}                               ? t8('This invoice has not been posted yet.')
                    : $has_further_invoice_for_advance_payment   ? t8('This invoice has a further invoice for advanced payment.')
                    : $has_final_invoice                         ? t8('This invoice has already a final invoice.')
                    : $is_invoice_for_advance_payment_from_order ? t8('This invoice was added from an order. See there.')
                    :                                              undef,
          only_if  => ($form->{type} eq "invoice_for_advance_payment" && $::instance_conf->get_show_invoice_for_advance_payment),
        ],
        action => [
          t8('Credit Note'),
          submit   => [ '#form', { action => "credit_note" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create              ? t8('You must not change this invoice.')
                    : $form->{type} eq "credit_note" ? t8('Credit notes cannot be converted into other credit notes.')
                    : !$form->{id}                   ? t8('This invoice has not been posted yet.')
                    : $form->{storno}                ? t8('A canceled invoice cannot be used. Please undo the cancellation first.')
                    :                                  undef,
        ],
        action => [
          t8('Sales Order'),
          submit   => [ '#form', { action => "order" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$form->{id} ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Reclamation'),
          submit   => ['#form', { action => "sales_reclamation" }], # can't call Reclamation directly
          disabled => !$form->{id} ? t8('This invoice has not been posted yet.') : undef,
          only_if  => ($::instance_conf->get_show_sales_reclamation && $::form->{type} eq 'invoice' && !$::form->{storno}),
        ],
      ], # end of combobox "Workflow"

      combobox => [
        action => [ t8('Export') ],
        action => [
          ($form->{id} ? t8('Print') : t8('Preview')),
          call     => [ 'kivi.SalesPurchase.show_print_dialog', $form->{id} ? 'print' : 'preview' ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create               ? t8('You must not print this invoice.')
                    : !$form->{id} && $form->{locked} ? t8('The billing period has already been locked.')
                    :                                   undef,
        ],
        action => [ t8('Print and Post'),
          call     => [ 'kivi.SalesPurchase.show_print_dialog', 'print_and_post' ],
          checks   => [ 'kivi.validate_form' ],
          confirm  => t8('The invoice is not linked with a sales delivery order. Post anyway?') x !!$warn_unlinked_delivery_order,
          disabled => !$may_edit_create                         ? t8('You must not change this invoice.')
                    : $form->{locked}                           ? t8('The billing period has already been locked.')
                    : $form->{storno}                           ? t8('A canceled invoice cannot be posted.')
                    : ($form->{id} && $change_never)            ? t8('Changing invoices has been disabled in the configuration.')
                    : ($form->{id} && $change_on_same_day_only) ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction               ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                                             undef,
        ],
        action => [ t8('E Mail'),
          call     => [ 'kivi.SalesPurchase.show_email_dialog' ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create       ? t8('You must not print this invoice.')
                    : !$form->{id}            ? t8('This invoice has not been posted yet.')
                    : $form->{postal_invoice} ? t8('This customer wants a postal invoices.')
                    :                     undef,
        ],
        action => [ t8('Factur-X/ZUGFeRD'),
          submit   => [ '#form', { action => "download_factur_x_xml" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create  ? t8('You must not print this invoice.')
                    : !$form->{id}       ? t8('This invoice has not been posted yet.')
                    : !$factur_x_enabled ? t8('Creating Factur-X/ZUGFeRD invoices is not enabled for this customer.')
                    :                      undef,
        ],
      ], # end of combobox "Export"

      combobox => [
        action => [ t8('more') ],
        action => [
          t8('History'),
          call     => [ 'set_history_window', $form->{id} * 1, 'glid' ],
          disabled => !$form->{id} ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Follow-Up'),
          call     => [ 'follow_up_window' ],
          disabled => !$form->{id} ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Drafts'),
          call     => [ 'kivi.Draft.popup', 'is', 'invoice', $form->{draft_id}, $form->{draft_description} ],
          disabled => !$may_edit_create ? t8('You must not change this invoice.')
                    :  $form->{id}      ? t8('This invoice has already been posted.')
                    : $form->{locked}   ? t8('The billing period has already been locked.')
                    :                     undef,
        ],
      ], # end of combobox "more"
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}

sub form_header {
  $main::lxdebug->enter_sub();

  _assert_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  my %TMPL_VAR = ();
  my @custom_hiddens;

  $TMPL_VAR{customer_obj} = SL::DB::Customer->load_cached($form->{customer_id}) if $form->{customer_id};
  $TMPL_VAR{invoice_obj}  = SL::DB::Invoice->load_cached($form->{id})           if $form->{id};

  # only print, no mail
  $form->{postal_invoice} = $TMPL_VAR{customer_obj}->postal_invoice if ref $TMPL_VAR{customer_obj} eq 'SL::DB::Customer';

  my $current_employee   = SL::DB::Manager::Employee->current;
  $form->{employee_id}   = $form->{old_employee_id} if $form->{old_employee_id};
  $form->{salesman_id}   = $form->{old_salesman_id} if $form->{old_salesman_id};
  $form->{employee_id} ||= $current_employee->id;
  $form->{salesman_id} ||= $current_employee->id;

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  if( $form->{customer_id} && !$form->{taxincluded_changed_by_user} ) {
    my $customer = SL::DB::Customer->load_cached($form->{customer_id});
    $form->{taxincluded} = defined($customer->taxincluded_checked) ? $customer->taxincluded_checked : $myconfig{taxincluded_checked};
  }
  $TMPL_VAR{taxincluded} = $form->{taxincluded};

  $form->get_lists("taxzones"      => ($form->{id} ? "ALL_TAXZONES" : "ALL_ACTIVE_TAXZONES"),
                   "currencies"    => "ALL_CURRENCIES",
                   "price_factors" => "ALL_PRICE_FACTORS");

  $form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;
  $form->{ALL_LANGUAGES}   = SL::DB::Manager::Language->get_all_sorted;
  $form->{ALL_DELIVERY_TERMS} = SL::DB::Manager::DeliveryTerm->get_valid($form->{delivery_term_id});

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
    or => [ and => [ trans_id  => $::form->{"$::form->{vc}_id"} * 1, module => 'CT' ], and => [ shipto_id => $::form->{shipto_id} * 1, trans_id => undef ] ]
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

  # qr reference
  my $has_qr_reference = $::instance_conf->get_create_qrbill_invoices == 1 &&
                         $form->{formname} eq 'invoice' ? 1 : 0;
  $TMPL_VAR{has_qr_reference} = $has_qr_reference;

  if ($has_qr_reference && defined $form->{qr_reference}) {
    $TMPL_VAR{qr_reference_formatted} = get_ref_number_formatted($form->{qr_reference});
  }

  # set option selected
  foreach my $item (qw(AR)) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  $TMPL_VAR{is_type_normal_invoice}                 = $form->{type} eq "invoice";
  $TMPL_VAR{is_type_credit_note}                    = $form->{type}   eq "credit_note";
  $TMPL_VAR{is_format_html}                         = $form->{format} eq 'html';
  $TMPL_VAR{dateformat}                             = $myconfig{dateformat};
  $TMPL_VAR{numberformat}                           = $myconfig{numberformat};
  $TMPL_VAR{longdescription_dialog_size_percentage} = SL::Helper::UserPreferences::DisplayPreferences->new()->get_longdescription_dialog_size_percentage();

  # hiddens
  $TMPL_VAR{HIDDENS} = [qw(
    id type queued printed emailed vc discount
    title creditlimit creditremaining tradediscount business closedto locked shipped storno storno_id
    max_dunning_level dunning_amount dunning_description
    taxaccounts cursor_fokus
    convert_from_reclamations_ids convert_from_do_ids convert_from_oe_ids convert_from_ar_ids useasnew
    invoice_id
    show_details
  ), @custom_hiddens,
  map { $_.'_rate', $_.'_description', $_.'_taxnumber', $_.'_tax_id' } split / /, $form->{taxaccounts}];

  $::request->{layout}->use_javascript(map { "${_}.js" } qw(kivi.Draft kivi.File kivi.SalesPurchase kivi.Part kivi.CustomerVendor kivi.Validator ckeditor5/ckeditor ckeditor5/translations/de kivi.io client_js autocomplete_chart));

  $TMPL_VAR{payment_terms_obj} = get_payment_terms_for_invoice();
  $form->{duedate}             = $TMPL_VAR{payment_terms_obj}->calc_date(reference_date => $form->{invdate}, due_date => $form->{duedate})->to_kivitendo if $TMPL_VAR{payment_terms_obj};

  setup_is_action_bar(\%TMPL_VAR);

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

  _assert_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{invtotal}    = $form->{invsubtotal};

  # tax, total and subtotal calculations
  my ($tax, $subtotal);
  $form->{taxaccounts_array} = [ split(/ /, $form->{taxaccounts}) ];

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

  my $grossamount = $form->{invtotal};
  $form->{invtotal} = $form->round_amount( $form->{invtotal}, 2, 1 );
  $form->{rounding} = $form->round_amount(
    $form->{invtotal} - $form->round_amount($grossamount, 2),
    2
  );

  # follow ups
  if ($form->{id}) {
    $form->{follow_ups}            = FU->follow_ups('trans_id' => $form->{id}, 'not_done' => 1) || [];
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

    #deaktivieren von gebuchten Zahlungen ausserhalb der Bücherkontrolle, vorher prüfen ob heute eingegeben
    if ($form->date_closed($form->{"gldate_$i"})) {
      $form->{"changeable_$i"} = 0;
    }
    # don't add manual bookings for charts which are assigned to real bank accounts
    # and are flagged for use with bank import
    my $bank_accounts = SL::DB::Manager::BankAccount->get_all();
    foreach my $bank (@{ $bank_accounts }) {
      if ($bank->use_with_bank_import) {
        my $accno_paid_bank = $bank->chart->accno;
        $form->{selectAR_paid} =~ s/<option>$accno_paid_bank--(.*?)<\/option>//;
      }
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

  my $shipto_cvars       = SL::DB::Shipto->new->cvars_by_config;
  foreach my $var (@{ $shipto_cvars }) {
    my $name = "shiptocvar_" . $var->config->name;
    $var->value($form->{$name}) if exists $form->{$name};
  }

  print $form->parse_html_template('is/form_footer', {
    is_type_normal_invoice              => ($form->{type} eq "invoice"),
    is_type_credit_note                 => ($form->{type} eq "credit_note"),
    totalpaid                           => $totalpaid,
    paid_missing                        => $form->{invtotal} - $totalpaid,
    print_options                       => setup_sales_purchase_print_options(),
    show_storno                         => $form->{id} && !$form->{storno} && !IS->has_storno(\%myconfig, $form, "ar") && !$totalpaid,
    show_delete                         => ($::instance_conf->get_is_changeable == 2)
                                             ? ($form->current_date(\%myconfig) eq $form->{gldate})
                                             : ($::instance_conf->get_is_changeable == 1),
    today                               => DateTime->today,
    vc_obj                              => $form->{customer_id} ? SL::DB::Customer->load_cached($form->{customer_id}) : undef,
    shipto_cvars                        => $shipto_cvars,
  });
##print $form->parse_html_template('is/_payments'); # parser
##print $form->parse_html_template('webdav/_list'); # parser

  $main::lxdebug->leave_sub();
}

sub mark_as_paid {
  $::auth->assert('invoice_edit');

  SL::DB::Invoice->new(id => $::form->{id})->load->mark_as_paid;

  $::form->redirect($::locale->text("Marked as paid"));
}

sub show_draft {
  # unless no lazy implementation of save draft without invdate
  # set the current date like in version <= 3.4.1
  $::form->{invdate}   = DateTime->today->to_lxoffice;
  $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;
  update();
}

sub update {
  $main::lxdebug->enter_sub();

  _assert_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my ($recursive_call) = @_;

  $form->{print_and_post} = 0         if $form->{second_run};
  $form->{update} = 1;

  if (($form->{previous_customer_id} || $form->{customer_id}) != $form->{customer_id}) {
    $::form->{salesman_id} = SL::DB::Manager::Employee->current->id if exists $::form->{salesman_id};

    IS->get_customer(\%myconfig, $form);
    $::form->{billing_address_id} = $::form->{default_billing_address_id};
  }

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);
  if ($form->{defaultcurrency} ne $form->{currency}) {
    if ($form->{exchangerate}) { # user input OR first default ->  leave this value
      $form->{exchangerate} = $form->parse_amount(\%myconfig, $form->{exchangerate}) unless $recursive_call;
      # does this differ from daily default?
      my $current_daily_rate = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{invdate}, 'buy');
      $form->{record_forex}  = $current_daily_rate > 0 && $current_daily_rate != $form->{exchangerate}
                           ?   1 : 0;
    } else {                     # no value, but get defaults -> maybe user changes invdate as well ...
      ($form->{exchangerate}, $form->{record_forex}) = $form->check_exchangerate(\%myconfig, $form->{currency},
                                                                                 $form->{invdate}, 'buy', $form->{id}, 'ar');
    }
  }
  for my $i (1 .. $form->{paidaccounts}) {
    next unless $form->{"paid_$i"};
    map { $form->{"${_}_$i"}   = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);
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
        $::dispatcher->end_request;

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
          && ($form->{"partnumber_$i" } eq "")
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
      $form->error($locale->text('Cannot post transaction above the maximum future booking date!'))
        if ($form->date_max_future($form->{"datepaid_$i"}, \%myconfig));

      #Zusätzlich noch das Buchungsdatum in die Bücherkontrolle einbeziehen
      # (Dient zur Prüfung ob ZE oder ZA geprüft werden soll)
      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($form->date_closed($form->{"datepaid_$i"})  && !$form->date_closed($form->{"gldate_$i"}, \%myconfig));
    }
  }

  #($form->{AR})      = split /--/, $form->{AR};
  $form->{AR}      = SL::DB::Manager::Chart->find_by( id => $form->{AR_chart_id} )->accno;
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
  $form->isblank("customer_id", $locale->text('Customer missing!'));
  $form->error($locale->text('Cannot post invoice for a closed period!'))
        if ($form->date_closed($form->{"invdate"}, \%myconfig));

  $form->{invnumber} =~ s/^\s*//g;
  $form->{invnumber} =~ s/\s*$//g;

  # if oldcustomer ne customer redo form
  if (($form->{previous_customer_id} || $form->{customer_id}) != $form->{customer_id}) {
    &update;
    $::dispatcher->end_request;
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

  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->isblank("exchangerate", $locale->text('Exchangerate missing!'));
    $form->error($locale->text('Cannot post invoice with negative exchange rate'))
      unless ($form->parse_amount(\%myconfig, $form->{"exchangerate"}) > 0);
  }

  # advance payment allows only one tax
  if ($form->{type} eq 'invoice_for_advance_payment') {
    my @current_taxaccounts = (split(/ /, $form->{taxaccounts}));
    $form->error($locale->text('Cannot post invoice for advance payment with more than one tax'))
      if (scalar @current_taxaccounts > 1);
    $form->error($locale->text('Cannot post invoice for advance payment with taxincluded'))
      if ($form->{taxincluded});
  }

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

      if ($form->{currency} ne $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($invdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  #($form->{AR})        = split /--/, $form->{AR};
  $form->{AR}      = SL::DB::Manager::Chart->find_by( id => $form->{AR_chart_id} )->accno;
  ($form->{AR_paid})   = split /--/, $form->{AR_paid};
  $form->{storno}    ||= 0;

  $form->{label} = $form->{type} eq 'credit_note' ? $locale->text('Credit Note') : $locale->text('Invoice');

  relink_accounts();

  my $terms        = get_payment_terms_for_invoice();
  $form->{duedate} = $terms->calc_date(reference_date => $form->{invdate}, due_date => $form->{duedate})->to_kivitendo if $terms;

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
        $form->error($locale->text('Cannot post invoice and/or transfer out! Error message:') . "\n" . join("\n", @errors));
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

  if(!exists $form->{addition}) {
    $form->{snumbers}  =  'invnumber' .'_'. $form->{invnumber}; # ($form->{type} eq 'credit_note' ? 'cnnumber' : 'invnumber') .'_'. $form->{invnumber};
    $form->{what_done} = 'invoice';
    $form->{addition}  = $form->{print_and_post} ? "PRINTED AND POSTED" :
                         $form->{storno}         ? "STORNO"             :
                                                   "POSTED";
    $form->save_history;
  }

  if ($form->{email_journal_id} && $form->{id} ne "") {
    my $invoice = SL::DB::Invoice->new(id => $form->{id})->load;
    my $email_journal = SL::DB::EmailJournal->new(
      id => delete $form->{email_journal_id}
    )->load;
    $email_journal->link_to_record_with_attachment($invoice, delete $::form->{email_attachment_id});
  }

  if (!$form->{no_redirect_after_post}) {
    $form->{action} = 'edit';
    $form->{script} = 'is.pl';
    $form->{callback} = build_std_url(qw(action edit id callback saved_message));
    $form->redirect($form->{label} . " $form->{invnumber} " . $locale->text('posted!'));
  }

  $main::lxdebug->leave_sub();
}

sub post_and_close {
  $main::lxdebug->enter_sub();
  my $locale   = $main::locale;
  my $form = $::form;

  $form->{no_redirect_after_post} = 1;
  &post();

  my $callback = $form->{callback}
    || "controller.pl?action=LoginScreen/user_login";
  my $msg = $form->{label} . " $form->{invnumber} " . $locale->text('posted!');
  SL::Helper::Flash::flash_later('info', $msg);
  print $form->redirect_header($callback);
  $::dispatcher->end_request;

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

  $form->{email_journal_id}    = delete $form->{workflow_email_journal_id};
  $form->{email_attachment_id} = delete $form->{workflow_email_attachment_id};
  $form->{callback}            = delete $form->{workflow_email_callback};

  delete @{ $form }{qw(printed emailed queued invnumber invdate exchangerate forex deliverydate id datepaid_1 gldate_1 acc_trans_id_1 source_1 memo_1 paid_1 exchangerate_1 AP_paid_1 storno locked qr_unstructured_message)};
  $form->{rowcount}--;
  $form->{paidaccounts} = 1;
  $form->{invdate}      = $form->current_date(\%myconfig);
  my $terms             = get_payment_terms_for_invoice();
  $form->{duedate}      = $terms ? $terms->calc_date(reference_date => $form->{invdate})->to_kivitendo : $form->{invdate};
  $form->{employee_id}  = SL::DB::Manager::Employee->current->id;
  $form->{forex}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{invdate}, 'buy');
  $form->{exchangerate} = $form->{forex} if $form->{forex};
  $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;

  $form->{"converted_from_invoice_id_$_"} = delete $form->{"invoice_id_$_"} for 1 .. $form->{"rowcount"};

  $form->{useasnew} = 1;
  &display_form;

  $main::lxdebug->leave_sub();
}

sub further_invoice_for_advance_payment {
  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('invoice_edit');

  $form->{email_journal_id}    = delete $form->{workflow_email_journal_id};
  $form->{email_attachment_id} = delete $form->{workflow_email_attachment_id};
  $form->{callback}            = delete $form->{workflow_email_callback};

  delete @{ $form }{qw(printed emailed queued invnumber invdate exchangerate forex deliverydate datepaid_1 gldate_1 acc_trans_id_1 source_1 memo_1 paid_1 exchangerate_1 AP_paid_1 storno locked)};
  $form->{convert_from_ar_ids} = $form->{id};
  $form->{id}                  = '';
  $form->{rowcount}--;
  $form->{paidaccounts}        = 1;
  $form->{invdate}             = $form->current_date(\%myconfig);
  my $terms                    = get_payment_terms_for_invoice();
  $form->{duedate}             = $terms ? $terms->calc_date(reference_date => $form->{invdate})->to_kivitendo : $form->{invdate};
  $form->{employee_id}         = SL::DB::Manager::Employee->current->id;
  $form->{forex}               = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{invdate}, 'buy');
  $form->{exchangerate}        = $form->{forex} if $form->{forex};
  $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;

  $form->{"converted_from_invoice_id_$_"} = delete $form->{"invoice_id_$_"} for 1 .. $form->{"rowcount"};

  &display_form;
}

sub final_invoice {
  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('invoice_edit');

  $form->{email_journal_id}    = delete $form->{workflow_email_journal_id};
  $form->{email_attachment_id} = delete $form->{workflow_email_attachment_id};
  $form->{callback}            = delete $form->{workflow_email_callback};

  my $related_invoices = IS->_get_invoices_for_advance_payment($form->{id});

  delete @{ $form }{qw(printed emailed queued invnumber invdate exchangerate forex deliverydate datepaid_1 gldate_1 acc_trans_id_1 source_1 memo_1 paid_1 exchangerate_1 AP_paid_1 storno locked)};

  $form->{convert_from_ar_ids} = $form->{id};
  $form->{id}                  = '';
  $form->{type}                = 'final_invoice';
  $form->{title}               = t8('Edit Final Invoice');
  $form->{paidaccounts}        = 1;
  $form->{invdate}             = $form->current_date(\%myconfig);
  my $terms                    = get_payment_terms_for_invoice();
  $form->{duedate}             = $terms ? $terms->calc_date(reference_date => $form->{invdate})->to_kivitendo : $form->{invdate};
  $form->{employee_id}         = SL::DB::Manager::Employee->current->id;
  $form->{forex}               = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{invdate}, 'buy');
  $form->{exchangerate}        = $form->{forex} if $form->{forex};
  $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;

  foreach my $i (1 .. $form->{"rowcount"}) {
    delete $form->{"id_$i"};
    delete $form->{"invoice_id_$i"};
    delete $form->{"parts_id_$i"};
    delete $form->{"partnumber_$i"};
    delete $form->{"description_$i"};
  }

  remove_emptied_rows(1);

  my $i = 0;
  foreach my $ri (@$related_invoices) {
    foreach my $item (@{$ri->items_sorted}) {
      $i++;
      $form->{"id_$i"}         = $item->parts_id;
      $form->{"partnumber_$i"} = $item->part->partnumber;
      $form->{"discount_$i"}   = $item->discount*100.0;
      $form->{"sellprice_$i"}  = $item->fxsellprice;
      $form->{$_ . "_" . $i}   = $item->$_       for qw(description longdescription qty price_factor_id unit active_price_source active_discount_source);

      $form->{$_ . "_" . $i}   = $form->format_amount(\%myconfig, $form->{$_ . "_" . $i}) for qw(qty sellprice discount);
    }
  }
  $form->{rowcount} = $i;

  update();
  $::dispatcher->end_request;
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

  my $email_journal_id    = delete $form->{workflow_email_journal_id};
  my $email_attachment_id = delete $form->{workflow_email_attachment_id};
  my $callback            = delete $form->{workflow_email_callback};
  map({ my $key = $_; delete($form->{$key}) unless (grep({ $key eq $_ } qw(id login password type))); } keys(%{ $form }));

  $form->{email_journal_id}    = $email_journal_id;
  $form->{email_attachment_id} = $email_attachment_id;
  $form->{callback}            = $callback;

  invoice_links();
  prepare_invoice();
  relink_accounts();

  # Payments must not be recorded for the new storno invoice.
  $form->{paidaccounts} = 0;
  map { my $key = $_; delete $form->{$key} if grep { $key =~ /^$_/ } qw(datepaid_ gldate_ acc_trans_id_ source_ memo_ paid_ exchangerate_ AR_paid_) } keys %{ $form };

  # record link invoice to storno
  $form->{convert_from_ar_ids} = $form->{id};
  $form->{storno_id} = $form->{id};
  $form->{storno} = 1;
  $form->{id} = "";
  $form->{invnumber} = "Storno zu " . $form->{invnumber};
  $form->{invdate}   = DateTime->today->to_lxoffice;
  $form->{rowcount}++;
  # set new ids for storno invoice
  # set new persistent ids for storno invoice items
  $form->{"converted_from_invoice_id_$_"} = delete $form->{"invoice_id_$_"} for 1 .. $form->{"rowcount"};

  $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;
  # post expects the field as user input
  $form->{exchangerate} = $form->format_amount(\%myconfig, $form->{exchangerate});
  $form->{script}       = 'is.pl';
  if ($form->{callback}) {
    post_and_close();
  } else {
    post();
  }
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

sub credit_note {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('invoice_edit');

  $form->{email_journal_id}    = delete $form->{workflow_email_journal_id};
  $form->{email_attachment_id} = delete $form->{workflow_email_attachment_id};
  $form->{callback}            = delete $form->{workflow_email_callback};

  $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;

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

sub credit_note_from_reclamation {
  $main::lxdebug->enter_sub();

  $main::auth->assert('invoice_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  if (!$form->{form_validity_token}) {
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;
  }

  my $from_id = delete $form->{from_id};
  my $reclamation = SL::DB::Reclamation->new(id => $from_id)->load;

  $reclamation->flatten_to_form($form, format_amounts => 1);

  # set new persistent ids for credit note and link previous reclamation id
  $form->{convert_from_reclamations_ids} = $form->{id};
  $form->{id}     = '';

  $form->{"converted_from_reclamation_items_id_$_"} = delete $form->{"reclamation_items_id_$_"} for 1 .. $form->{"rowcount"};

  $form->{transdate} = $form->{invdate} = $form->current_date(\%myconfig);
  $form->{duedate} =
    $form->current_date(\%myconfig, $form->{invdate}, $form->{terms} * 1);

  $form->{title}  = $locale->text('Add Credit Note');
  $form->{script} = 'is.pl';

  # bo creates the id, reset it
  map { delete $form->{$_} }
    qw(id invnumber subject message cc bcc printed emailed queued);
  $form->{ $form->{vc} } =~ s/--.*//g;

  $form->{type} = "credit_note";

  my $currency = $form->{currency};
  &invoice_links;
  $form->{currency}     = $currency;
  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{invdate}, 'buy');
  $form->{exchangerate} = $form->{forex} || '';

  $form->{creditremaining} -= ($form->{oldinvtotal} - $form->{ordtotal});

  &prepare_invoice;

  &display_form;

  $main::lxdebug->leave_sub();
}

sub display_form {
  $::lxdebug->enter_sub;

  _assert_access();

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

sub delete {
  $::auth->assert('invoice_edit');

  if (IS->delete_invoice(\%::myconfig, $::form)) {
    # saving the history
    if(!exists $::form->{addition}) {
      $::form->{snumbers}  = 'invnumber' .'_'. $::form->{invnumber};
      $::form->{what_done} = 'invoice';
      $::form->{addition}  = "DELETED";
      $::form->save_history;
    }
    # /saving the history
    $::form->redirect($::locale->text('Invoice deleted!'));
  }
  $::form->error($::locale->text('Cannot delete invoice!'));
}

sub dispatcher {
  for my $action (qw(
    print update ship_to storno post_payment use_as_new credit_note
    delete post order preview post_and_e_mail print_and_post
    mark_as_paid
  )) {
    if ($::form->{"action_$action"}) {
      call_sub($action);
      return;
    }
  }

  $::form->error($::locale->text('No action defined.'));
}
