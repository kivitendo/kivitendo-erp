#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
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
# Accounts Payables database backend routines
#
#======================================================================

package AP;

use SL::DATEV qw(:CONSTANTS);
use SL::DBUtils;
use SL::IO;
use SL::MoreCommon;
use SL::DB::ApGl;
use SL::DB::Default;
use SL::DB::Draft;
use SL::DB::Order;
use SL::DB::PurchaseInvoice;
use SL::DB::EmailJournal;
use SL::DB::ValidityToken;
use SL::Util qw(trim);
use SL::DB;
use Data::Dumper;
use List::Util qw(sum0);
use strict;
use URI::Escape;

sub post_transaction {
  my ($self, $myconfig, $form, $provided_dbh, %params) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_post_transaction, $self, $myconfig, $form, $provided_dbh, %params);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _post_transaction {
  my ($self, $myconfig, $form, $provided_dbh, %params) = @_;

  my $validity_token;
  if (!$form->{id}) {
    $validity_token = SL::DB::Manager::ValidityToken->fetch_valid_token(
      scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST(),
      token => $form->{form_validity_token},
    );

    die $::locale->text('The form is not valid anymore.') if !$validity_token;
  }

  my $payments_only = $params{payments_only};
  my $dbh = $provided_dbh || SL::DB->client->dbh;

  my ($null, $taxrate, $amount);
  my $exchangerate = 0;

  $form->{defaultcurrency} = $form->get_default_currency($myconfig);
  $form->{taxincluded} = 0 unless $form->{taxincluded};
  $form->{script}      = 'ap.pl' unless $form->{script};

  # make sure to have a id
  my ($query, $sth, @values);
  if (!$payments_only) {
    # if we have an id delete old records
    if ($form->{id}) {

      # delete detail records
      $query = qq|DELETE FROM acc_trans WHERE trans_id = ?|;
      do_query($form, $dbh, $query, $form->{id});

    } else {

      ($form->{id}) = selectrow_query($form, $dbh, qq|SELECT nextval('glid')|);

      $query =
        qq|INSERT INTO ap (id, invnumber, employee_id,currency_id, taxzone_id) | .
        qq|VALUES (?, ?, (SELECT e.id FROM employee e WHERE e.login = ?),
                      (SELECT id FROM currencies WHERE name = ?), (SELECT taxzone_id FROM vendor WHERE id = ?) )|;
      do_query($form, $dbh, $query, $form->{id}, $form->{invnumber}, $::myconfig{login}, $form->{currency}, $form->{vendor_id});

    }
  }
  # check default or record exchangerate
  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate         = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'sell');
    $form->{exchangerate} = $form->parse_amount($myconfig, $form->{exchangerate}, 5);

    # if default exchangerate is not defined, define one
    unless ($exchangerate) {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, 0,  $form->{exchangerate});
      # delete records exchangerate -> if user sets new invdate for record
      $query = qq|UPDATE ap set exchangerate = NULL where id = ?|;
      do_query($form, $dbh, $query, $form->{"id"});
    }
    # update record exchangerate, if the default is set and differs from current
    if ($exchangerate && ($form->{exchangerate} != $exchangerate)) {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate},
                                 0, $form->{exchangerate}, $form->{id}, 'ap');
    }
  }
  # get the charts selected
  $form->{AP_amounts}{"amount_$_"} = $form->{"AP_amount_chart_id_$_"} for (1 .. $form->{rowcount});

  # calculate the totals while calculating and reformatting the $amount_$i and $tax_$i
  ($form->{netamount},$form->{total_tax},$form->{invtotal}) = $form->calculate_arap('buy',$form->{taxincluded}, $form->{exchangerate});

  # adjust paidaccounts if there is no date in the last row
  $form->{paidaccounts}-- unless ($form->{"datepaid_$form->{paidaccounts}"});

  $form->{invpaid} = 0;

  # add payments
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} =
      $form->round_amount($form->parse_amount($myconfig, $form->{"paid_$i"}),
                          2);

    $form->{invpaid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"};

  }

  $form->{invpaid} =
    $form->round_amount($form->{invpaid} * $form->{exchangerate}, 2);

  # # store invoice total, this goes into ap table
  # $form->{invtotal} = $form->{netamount} + $form->{total_tax};

  # amount for total AP
  $form->{payables} = $form->{invtotal};

  if (!$payments_only) {
    $query = qq|UPDATE ap SET invnumber = ?,
                transdate = ?, ordnumber = ?, vendor_id = ?, taxincluded = ?,
                amount = ?, duedate = ?, deliverydate = ?, tax_point = ?, paid = ?, netamount = ?,
                currency_id = (SELECT id FROM currencies WHERE name = ?), notes = ?, department_id = ?, storno = ?, storno_id = ?,
                globalproject_id = ?, direct_debit = ?, payment_id = ?, transaction_description = ?, intnotes = ?,
                qrbill_data = ?
               WHERE id = ?|;
    @values = ($form->{invnumber}, conv_date($form->{transdate}),
                  $form->{ordnumber}, conv_i($form->{vendor_id}),
                  $form->{taxincluded} ? 't' : 'f', $form->{invtotal},
                  conv_date($form->{duedate}), conv_date($form->{deliverydate}), conv_date($form->{tax_point}),
                  $form->{invpaid}, $form->{netamount},
                  $form->{currency}, $form->{notes},
                  conv_i($form->{department_id}), $form->{storno},
                  $form->{storno_id}, conv_i($form->{globalproject_id}),
                  $form->{direct_debit} ? 't' : 'f',
                  conv_i($form->{payment_id}), $form->{transaction_description},
                  $form->{intnotes},
                  $form->{qrbill_data_encoded} ? uri_unescape($form->{qrbill_data_encoded}) : undef,
                  $form->{id});
    do_query($form, $dbh, $query, @values);

    $form->new_lastmtime('ap');

    # Link this record to the record it was created from.
    my $convert_from_oe_id = delete $form->{convert_from_oe_id};
    if ($convert_from_oe_id) {
      RecordLinks->create_links('dbh'        => $dbh,
                                'mode'       => 'ids',
                                'from_table' => 'oe',
                                'from_ids'   => $convert_from_oe_id,
                                'to_table'   => 'ap',
                                'to_id'      => $form->{id},
      );

      # Close the record it was created from if the amount of
      # all APs create from this record equals the records amount.
      my @links = RecordLinks->get_links('dbh'        => $dbh,
                                         'from_table' => 'oe',
                                         'from_id'    => $convert_from_oe_id,
                                         'to_table'   => 'ap',
      );

      my $amount_sum = sum0 map { SL::DB::PurchaseInvoice->new(id => $_->{to_id})->load->amount } @links;
      my $order      = SL::DB::Order->new(id => $convert_from_oe_id)->load;

      $order->update_attributes(closed => 1) if ($amount_sum - $order->amount) == 0;
    }

    # add individual transactions
    for my $i (1 .. $form->{rowcount}) {
      if ($form->{"amount_$i"} != 0) {
        my $project_id;
        $project_id = conv_i($form->{"project_id_$i"});

        # insert detail records in acc_trans
        $query =
          qq|INSERT INTO acc_trans | .
          qq|  (trans_id, chart_id, amount, transdate, project_id, taxkey, tax_id, chart_link)| .
          qq|VALUES (?, ?,   ?, ?, ?, ?, ?, (SELECT c.link FROM chart c WHERE c.id = ?))|;
        @values = ($form->{id}, $form->{"AP_amount_chart_id_$i"},
                   $form->{"amount_$i"}, conv_date($form->{transdate}),
                   $project_id, $form->{"taxkey_$i"}, conv_i($form->{"tax_id_$i"}),
                   $form->{"AP_amount_chart_id_$i"});
        do_query($form, $dbh, $query, @values);

        if ($form->{"tax_$i"} != 0 && !$form->{"reverse_charge_$i"}) {
          # insert detail records in acc_trans
          $query =
            qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, | .
            qq|  project_id, taxkey, tax_id, chart_link) | .
            qq|VALUES (?, (SELECT c.id FROM chart c WHERE c.accno = ?), | .
            qq|  ?, ?, ?, ?, ?,| .
            qq| (SELECT c.link FROM chart c WHERE c.accno = ?))|;
          @values = ($form->{id}, $form->{AP_amounts}{"tax_$i"},
                     $form->{"tax_$i"}, conv_date($form->{transdate}),
                     $project_id, $form->{"taxkey_$i"}, conv_i($form->{"tax_id_$i"}),
                     $form->{AP_amounts}{"tax_$i"});
          do_query($form, $dbh, $query, @values);
        }

      }
    }

    # add payables
    $query =
      qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, taxkey, tax_id, chart_link) | .
      qq|VALUES (?, ?, ?, ?, | .
      qq|        (SELECT taxkey_id FROM chart WHERE id = ?),| .
      qq|        (SELECT tax_id| .
      qq|         FROM taxkeys| .
      qq|         WHERE chart_id = ?| .
      qq|         AND startdate <= ?| .
      qq|         ORDER BY startdate DESC LIMIT 1),| .
      qq|        (SELECT c.link FROM chart c WHERE c.id = ?))|;
    @values = ($form->{id}, $form->{AP_chart_id}, $form->{payables},
               conv_date($form->{transdate}), $form->{AP_chart_id}, $form->{AP_chart_id}, conv_date($form->{transdate}),
               $form->{AP_chart_id});
    do_query($form, $dbh, $query, @values);
  }

  # if there is no amount but a payment record a payable
  if ($form->{amount} == 0 && $form->{invtotal} == 0) {
    $form->{payables} = $form->{invpaid};
  }

  my %already_cleared = %{ $params{already_cleared} // {} };

  # add paid transactions
  for my $i (1 .. $form->{paidaccounts}) {

    if ($form->{"acc_trans_id_$i"} && $payments_only && (SL::DB::Default->get->payments_changeable == 0)) {
      next;
    }

    if ($form->{"paid_$i"} != 0) {
      my $project_id = conv_i($form->{"paid_project_id_$i"});

      $exchangerate = 0;
      if ($form->{currency} eq $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = 1;
      } else {
        $exchangerate              = $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell');
        $form->{"exchangerate_$i"} = $exchangerate || $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }
      $form->{"AP_paid_$i"} =~ s/\"//g;

      # get paid account

      ($form->{"AP_paid_account_$i"}) = split(/--/, $form->{"AP_paid_$i"});
      $form->{"datepaid_$i"} = $form->{transdate}
        unless ($form->{"datepaid_$i"});

      # if there is no amount and invtotal is zero there is no exchangerate
      if ($form->{amount} == 0 && $form->{invtotal} == 0) {
        $form->{exchangerate} = $form->{"exchangerate_$i"};
      }

      $amount =
        $form->round_amount($form->{"paid_$i"} * $form->{exchangerate} * -1,
                            2);

      my $new_cleared = !$form->{"acc_trans_id_$i"}                                                             ? 'f'
                      : !$already_cleared{$form->{"acc_trans_id_$i"}}                                           ? 'f'
                      : $already_cleared{$form->{"acc_trans_id_$i"}}->{amount} != $amount * -1                  ? 'f'
                      : $already_cleared{$form->{"acc_trans_id_$i"}}->{accno}  != $form->{"AP_paid_account_$i"} ? 'f'
                      : $already_cleared{$form->{"acc_trans_id_$i"}}->{cleared}                                 ? 't'
                      :                                                                                           'f';

      if ($form->{payables}) {
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, cleared, taxkey, tax_id, chart_link) | .
          qq|VALUES (?, ?, ?, ?, ?, ?, | .
          qq|        (SELECT taxkey_id FROM chart WHERE id = ?),| .
          qq|        (SELECT tax_id| .
          qq|         FROM taxkeys| .
          qq|         WHERE chart_id = ?| .
          qq|         AND startdate <= ?| .
          qq|         ORDER BY startdate DESC LIMIT 1),| .
          qq|        (SELECT c.link FROM chart c WHERE c.id = ?))|;
        @values = ($form->{id}, $form->{AP_chart_id}, $amount,
                   conv_date($form->{"datepaid_$i"}), $project_id, $new_cleared,
                   $form->{AP_chart_id}, $form->{AP_chart_id}, conv_date($form->{"datepaid_$i"}),
                   $form->{AP_chart_id});
        do_query($form, $dbh, $query, @values);
      }
      $form->{payables} = $amount;

      # add payment
      my $gldate = (conv_date($form->{"gldate_$i"}))? conv_date($form->{"gldate_$i"}) : conv_date($form->current_date($myconfig));
      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, gldate, source, memo, project_id, cleared, taxkey, tax_id, chart_link) | .
        qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?, ?, ?, ?, | .
        qq|        (SELECT taxkey_id FROM chart WHERE accno = ?), | .
        qq|        (SELECT tax_id| .
        qq|         FROM taxkeys| .
        qq|         WHERE chart_id= (SELECT id | .
        qq|                          FROM chart| .
        qq|                          WHERE accno = ?)| .
        qq|         AND startdate <= ?| .
        qq|         ORDER BY startdate DESC LIMIT 1),| .
        qq|        (SELECT c.link FROM chart c WHERE c.accno = ?))|;
      @values = ($form->{id}, $form->{"AP_paid_account_$i"}, $form->{"paid_$i"},
                 conv_date($form->{"datepaid_$i"}), $gldate, $form->{"source_$i"},
                 $form->{"memo_$i"}, $project_id, $new_cleared, $form->{"AP_paid_account_$i"},
                 $form->{"AP_paid_account_$i"}, conv_date($form->{"datepaid_$i"}),
                 $form->{"AP_paid_account_$i"});
      do_query($form, $dbh, $query, @values);

      # add exchange rate difference
      $amount =
        $form->round_amount($form->{"paid_$i"} *
                            ($form->{"exchangerate_$i"} - 1), 2);
      if ($amount != 0) {
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, fx_transaction, cleared, project_id, taxkey, tax_id, chart_link) | .
          qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, 't', 'f', ?, | .
          qq|        (SELECT taxkey_id FROM chart WHERE accno = ?), | .
          qq|        (SELECT tax_id| .
          qq|         FROM taxkeys| .
          qq|         WHERE chart_id= (SELECT id | .
          qq|                          FROM chart| .
          qq|                          WHERE accno = ?)| .
          qq|         AND startdate <= ?| .
          qq|         ORDER BY startdate DESC LIMIT 1),| .
          qq|        (SELECT c.link FROM chart c WHERE c.accno = ?))|;
        @values = ($form->{id}, $form->{"AP_paid_account_$i"}, $amount,
                   conv_date($form->{"datepaid_$i"}), $project_id,
                   $form->{"AP_paid_account_$i"},
                   $form->{"AP_paid_account_$i"}, conv_date($form->{"datepaid_$i"}),
                   $form->{"AP_paid_account_$i"});
        do_query($form, $dbh, $query, @values);
      }

      # exchangerate gain/loss
      $amount =
        $form->round_amount($form->{"paid_$i"} *
                            ($form->{exchangerate} -
                             $form->{"exchangerate_$i"}), 2);

      if ($amount != 0) {
        # fetch fxgain and fxloss chart info from defaults if charts aren't already filled in form
        if ( !$form->{fxgain_accno} && $::instance_conf->get_fxgain_accno_id ) {
          $form->{fxgain_accno} = SL::DB::Manager::Chart->find_by(id => $::instance_conf->get_fxgain_accno_id)->accno;
        };
        if ( !$form->{fxloss_accno} && $::instance_conf->get_fxloss_accno_id ) {
          $form->{fxloss_accno} = SL::DB::Manager::Chart->find_by(id => $::instance_conf->get_fxloss_accno_id)->accno;
        };
        die "fxloss_accno missing" if $amount < 0 and not $form->{fxloss_accno};
        die "fxgain_accno missing" if $amount > 0 and not $form->{fxgain_accno};
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, fx_transaction, cleared, project_id, taxkey, tax_id, chart_link) | .
          qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, 't', 'f', ?, | .
          qq|        (SELECT taxkey_id FROM chart WHERE accno = ?),| .
          qq|        (SELECT tax_id| .
          qq|         FROM taxkeys| .
          qq|         WHERE chart_id= (SELECT id | .
          qq|                          FROM chart| .
          qq|                          WHERE accno = ?)| .
          qq|         AND startdate <= ?| .
          qq|         ORDER BY startdate DESC LIMIT 1),| .
          qq|        (SELECT c.link FROM chart c WHERE c.accno = ?))|;
        @values = ($form->{id},
                   ($amount > 0) ? $form->{fxgain_accno} : $form->{fxloss_accno},
                   $amount, conv_date($form->{"datepaid_$i"}), $project_id,
                   ($amount > 0) ? $form->{fxgain_accno} : $form->{fxloss_accno},
                   ($amount > 0) ? $form->{fxgain_accno} : $form->{fxloss_accno}, conv_date($form->{"datepaid_$i"}),
                   ($amount > 0) ? $form->{fxgain_accno} : $form->{fxloss_accno});
        do_query($form, $dbh, $query, @values);
      }

      # update exchange rate record
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
        $form->update_exchangerate($dbh, $form->{currency},
                                   $form->{"datepaid_$i"},
                                   0, $form->{"exchangerate_$i"});
      }
    }
  }

  if ($payments_only) {
    $query = qq|UPDATE ap SET paid = ?, datepaid = ? WHERE id = ?|;
    do_query($form, $dbh, $query,  $form->{invpaid}, $form->{invpaid} ? conv_date($form->{datepaid}) : undef, conv_i($form->{id}));
    $form->new_lastmtime('ap');
  }

  IO->set_datepaid(table => 'ap', id => $form->{id}, dbh => $dbh);

  if ($form->{draft_id}) {
    SL::DB::Manager::Draft->delete_all(where => [ id => delete($form->{draft_id}) ]);
  }

  # hook for taxkey 94
  $self->_reverse_charge($myconfig, $form) unless $payments_only;
  # safety check datev export
  if ($::instance_conf->get_datev_check_on_ap_transaction) {
    my $datev = SL::DATEV->new(
      dbh        => $dbh,
      trans_id   => $form->{id},
    );
    $datev->generate_datev_data;

    if ($datev->errors) {
      die join "\n", $::locale->text('DATEV check returned errors:'), $datev->errors;
    }
  }

  $validity_token->delete if $validity_token;
  delete $form->{form_validity_token};

  return 1;
}

sub _reverse_charge {
  my ($self, $myconfig, $form) = @_;

  # delete previous bookings, if they exists (repost)
  my $ap_gl = SL::DB::Manager::ApGl->get_first(where => [ ap_id => $form->{id} ]);
  my $gl_id = ref $ap_gl eq 'SL::DB::ApGl' ? $ap_gl->gl_id : undef;

  SL::DB::Manager::GLTransaction->delete_all(where => [ id    => $gl_id ])       if $gl_id;
  SL::DB::Manager::ApGl->         delete_all(where => [ ap_id => $form->{id} ])  if $gl_id;
  SL::DB::Manager::RecordLink->   delete_all(where => [ from_table => 'ap', to_table => 'gl', from_id => $form->{id} ]);

  my ($i, $current_transaction);

  for $i (1 .. $form->{rowcount}) {

    my $tax = SL::DB::Manager::Tax->get_first( where => [id => $form->{"tax_id_$i"}, '!reverse_charge_chart_id' => undef ]);
    next unless ref $tax eq 'SL::DB::Tax';

    # gl booking
    my ($credit, $debit);
    $credit   = SL::DB::Manager::Chart->find_by(id => $tax->chart_id);
    $debit    = SL::DB::Manager::Chart->find_by(id => $tax->reverse_charge_chart_id);

    croak("No such Chart ID" . $tax->chart_id)          unless ref $credit eq 'SL::DB::Chart';
    croak("No such Chart ID" . $tax->reverse_chart_id)  unless ref $debit  eq 'SL::DB::Chart';

    my ($tmpnetamount, $tmptaxamount) = $form->calculate_tax($form->{"amount_$i"}, $tax->rate, $form->{taxincluded}, 2);
    $current_transaction = SL::DB::GLTransaction->new(
          employee_id    => $form->{employee_id},
          transdate      => $form->{transdate},
          description    => $form->{notes} || $form->{invnumber},
          reference      => $form->{invnumber},
          department_id  => $form->{department_id} ? $form->{department_id} : undef,
          imported       => 0, # not imported
          taxincluded    => 0,
        )->add_chart_booking(
          chart  => $tmptaxamount > 0 ? $debit : $credit,
          debit  => abs($tmptaxamount),
          source => "Reverse Charge for " . $form->{invnumber},
          tax_id => 0,
        )->add_chart_booking(
          chart  => $tmptaxamount > 0 ? $credit : $debit,
          credit => abs($tmptaxamount),
          source => "Reverse Charge for " . $form->{invnumber},
          tax_id => 0,
      )->post;
    # add a stable link from ap to gl
    my %props_gl = (
        ap_id => $form->{id},
        gl_id => $current_transaction->id,
      );
    SL::DB::ApGl->new(%props_gl)->save;
    # Record a record link from ap to gl
    my %props_rl = (
        from_table => 'ap',
        from_id    => $form->{id},
        to_table   => 'gl',
        to_id      => $current_transaction->id,
      );
    SL::DB::RecordLink->new(%props_rl)->save;
  }
}

sub delete_transaction {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  SL::DB->client->with_transaction(sub {

    # if tax 94 reverse charge, clear all GL bookings and links
    my $ap_gl = SL::DB::Manager::ApGl->get_first(where => [ ap_id => $form->{id} ]);
    my $gl_id = ref $ap_gl eq 'SL::DB::ApGl' ? $ap_gl->gl_id : undef;

    SL::DB::Manager::GLTransaction->delete_all(where => [ id    => $gl_id ])       if $gl_id;
    SL::DB::Manager::ApGl->         delete_all(where => [ ap_id => $form->{id} ])  if $gl_id;
    SL::DB::Manager::RecordLink->   delete_all(where => [ from_table => 'ap', to_table => 'gl', from_id => $form->{id} ]);
    # done gl delete for tax 94 case

    # begin ap delete
    my $query = qq|DELETE FROM ap WHERE id = ?|;
    do_query($form, SL::DB->client->dbh, $query, $form->{id});
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();

  return 1;
}

sub ap_transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  my $query =
    qq|SELECT a.id, a.invnumber, a.transdate, a.duedate, a.amount, a.paid, | .
    qq|  a.ordnumber, v.name, a.invoice, a.netamount, a.datepaid, a.notes, | .
    qq|  a.intnotes, a.globalproject_id, a.storno, a.storno_id, a.direct_debit, | .
    qq|  a.transaction_description, a.itime::DATE AS insertdate, | .
    qq|  pr.projectnumber AS globalprojectnumber, | .
    qq|  e.name AS employee, | .
    qq|  v.vendornumber, v.country, v.ustid, | .
    qq|  tz.description AS taxzone, | .
    qq|  pt.description AS payment_terms, | .
    qq|  department.description AS department, | .
    qq{  ( SELECT ch.accno || ' -- ' || ch.description
           FROM acc_trans at
           LEFT JOIN chart ch ON ch.id = at.chart_id
           WHERE ch.link ~ 'AP[[:>:]]'
            AND at.trans_id = a.id
            LIMIT 1
          ) AS charts, } .
    qq{  ( SELECT ch.accno || ' -- ' || ch.description
           FROM acc_trans at
           LEFT JOIN chart ch ON ch.id = at.chart_id
           WHERE ch.link ~ 'AP_amount'
            AND at.trans_id = a.id
            LIMIT 1
          ) AS debit_chart } .
    qq|FROM ap a | .
    qq|JOIN vendor v ON (a.vendor_id = v.id) | .
    qq|LEFT JOIN contacts cp ON (a.cp_id = cp.cp_id) | .
    qq|LEFT JOIN employee e ON (a.employee_id = e.id) | .
    qq|LEFT JOIN project pr ON (a.globalproject_id = pr.id) | .
    qq|LEFT JOIN tax_zones tz ON (tz.id = a.taxzone_id)| .
    qq|LEFT JOIN payment_terms pt ON (pt.id = a.payment_id)| .
    qq|LEFT JOIN department ON (department.id = a.department_id)|;

  my $where = '';

  my @values;

  # Permissions:
  # - Always return invoices & AP transactions for projects the employee has "view invoices" permissions for, no matter what the other rules say.
  # - Exclude AP transactions if no permissions for them exist.
  # - Limit to own invoices unless may edit all invoices or view invoices is allowed.
  # - If may edit all or view invoices is allowed, allow filtering by employee.
  my (@permission_where, @permission_values);

  if ($::auth->assert('vendor_invoice_edit', 1) || $::auth->assert('purchase_invoice_view', 1)) {
    if (!$::auth->assert('show_ap_transactions', 1)) {
      push @permission_where, "NOT invoice = 'f'"; # remove ap transactions from Purchase -> Reports -> Invoices
    }

    if (!$::auth->assert('purchase_all_edit', 1) && !$::auth->assert('purchase_invoice_view', 1)) {
      # only show own invoices
      push @permission_where,  "a.employee_id = ?";
      push @permission_values, SL::DB::Manager::Employee->current->id;

    } else {
      if ($form->{employee_id}) {
        push @permission_where,  "a.employee_id = ?";
        push @permission_values, conv_i($form->{employee_id});
      }
    }
  }

  if (@permission_where || (!$::auth->assert('vendor_invoice_edit', 1) && !$::auth->assert('purchase_invoice_view', 1))) {
    my $permission_where_str = @permission_where ? "OR (" . join(" AND ", map { "($_)" } @permission_where) . ")" : "";
    $where .= qq|
      AND (   (a.globalproject_id IN (
               SELECT epi.project_id
               FROM employee_project_invoices epi
               WHERE epi.employee_id = ?))
           $permission_where_str)
    |;
    push @values, SL::DB::Manager::Employee->current->id, @permission_values;
  }

  if ($form->{vendor}) {
    $where .= " AND v.name ILIKE ?";
    push(@values, like($form->{vendor}));
  }
  if ($form->{"cp_name"}) {
    $where .= " AND (cp.cp_name ILIKE ? OR cp.cp_givenname ILIKE ?)";
    push(@values, (like($form->{"cp_name"}))x2);
  }
  if ($form->{department_id}) {
    $where .= " AND a.department_id = ?";
    push(@values, $form->{department_id});
  }
  if ($form->{invnumber}) {
    $where .= " AND a.invnumber ILIKE ?";
    push(@values, like($form->{invnumber}));
  }
  if ($form->{ordnumber}) {
    $where .= " AND a.ordnumber ILIKE ?";
    push(@values, like($form->{ordnumber}));
  }
  if ($form->{taxzone_id}) {
    $where .= " AND a.taxzone_id = ?";
    push(@values, $form->{taxzone_id});
  }
  if ($form->{payment_id}) {
    $where .= " AND a.payment_id = ?";
    push(@values, $form->{payment_id});
  }
  if ($form->{transaction_description}) {
    $where .= " AND a.transaction_description ILIKE ?";
    push(@values, like($form->{transaction_description}));
  }
  if ($form->{notes}) {
    $where .= " AND a.notes ILIKE ?";
    push(@values, like($form->{notes}));
  }
  if ($form->{intnotes}) {
    $where .= " AND a.intnotes ILIKE ?";
    push(@values, like($form->{intnotes}));
  }
  if ($form->{project_id}) {
    $where .=
      qq| AND ((a.globalproject_id = ?) OR EXISTS | .
      qq|  (SELECT * FROM invoice i | .
      qq|   WHERE i.project_id = ? AND i.trans_id = a.id) | .
      qq| OR EXISTS | .
      qq|  (SELECT * FROM acc_trans at | .
      qq|   WHERE at.project_id = ? AND at.trans_id = a.id)| .
      qq|  )|;
    push(@values, $form->{project_id}, $form->{project_id}, $form->{project_id});
  }

  if ($form->{transdatefrom}) {
    $where .= " AND a.transdate >= ?";
    push(@values, trim($form->{transdatefrom}));
  }
  if ($form->{transdateto}) {
    $where .= " AND a.transdate <= ?";
    push(@values, trim($form->{transdateto}));
  }
  if ($form->{duedatefrom}) {
    $where .= " AND a.duedate >= ?";
    push(@values, trim($form->{duedatefrom}));
  }
  if ($form->{duedateto}) {
    $where .= " AND a.duedate <= ?";
    push(@values, trim($form->{duedateto}));
  }
  if ($form->{datepaidfrom}) {
    $where .= " AND a.datepaid >= ?";
    push(@values, trim($form->{datepaidfrom}));
  }
  if ($form->{datepaidto}) {
    $where .= " AND a.datepaid <= ?";
    push(@values, trim($form->{datepaidto}));
  }
  if ($form->{insertdatefrom}) {
    $where .= " AND a.itime >= ?";
    push(@values, trim($form->{insertdatefrom}));
  }
  if ($form->{insertdateto}) {
    $where .= " AND a.itime <= ?";
    push(@values, trim($form->{insertdateto}));
  }
  if ($form->{open} || $form->{closed}) {
    unless ($form->{open} && $form->{closed}) {
      $where .= " AND a.amount <> a.paid" if ($form->{open});
      $where .= " AND a.amount = a.paid"  if ($form->{closed});
    }
  }

  $form->{fulltext} = trim($form->{fulltext});
  if ($form->{fulltext}) {
    my @fulltext_fields = qw(a.notes
                             a.intnotes
                             a.shipvia
                             a.transaction_description
                             a.quonumber
                             a.ordnumber
                             a.invnumber);
    $where .= ' AND (';
    $where .= join ' OR ', map {"$_ ILIKE ?"} @fulltext_fields;

    $where .= <<SQL;
      OR EXISTS (
        SELECT files.id FROM files LEFT JOIN file_full_texts ON (file_full_texts.file_id = files.id)
          WHERE files.object_id = a.id AND files.object_type = 'purchase_invoice'
            AND file_full_texts.full_text ILIKE ?)
SQL
    $where .= ')'; # end AND

    push(@values, like($form->{fulltext})) for 1 .. (scalar @fulltext_fields) + 1;
  }

  if ($form->{parts_partnumber}) {
    $where .= <<SQL;
 AND EXISTS (
        SELECT invoice.trans_id
        FROM invoice
        LEFT JOIN parts ON (invoice.parts_id = parts.id)
        WHERE (invoice.trans_id = a.id)
          AND (parts.partnumber ILIKE ?)
        LIMIT 1
      )
SQL
    push @values, like($form->{parts_partnumber});
  }

  if ($form->{parts_description}) {
    $where .= <<SQL;
 AND EXISTS (
        SELECT invoice.trans_id
        FROM invoice
        WHERE (invoice.trans_id = a.id)
          AND (invoice.description ILIKE ?)
        LIMIT 1
      )
SQL
    push @values, like($form->{parts_description});
  }

  if ($where) {
    $where  =~ s{\s*AND\s*}{ WHERE };
    $query .= $where;
  }

  my @a = qw(transdate invnumber name);
  push @a, "employee" if $form->{l_employee};
  my $sortdir   = !defined $form->{sortdir} ? 'ASC' : $form->{sortdir} ? 'ASC' : 'DESC';
  my $sortorder = join(', ', map { "$_ $sortdir" } @a);

  if (grep({ $_ eq $form->{sort} } qw(transdate id invnumber ordnumber name netamount tax amount paid datepaid due duedate notes employee transaction_description direct_debit department taxzone insertdate))) {
    $sortorder = $form->{sort} . " $sortdir";
  }

  $query .= " ORDER BY $sortorder";

  my @result = selectall_hashref_query($form, $dbh, $query, @values);

  $form->{AP} = [ @result ];

  if ($form->{l_items} && scalar @{ $form->{AP} }) {
    my ($items_query, $items_sth);
    if ($form->{l_items}) {
      $items_query =
        qq|SELECT id
          FROM invoice
          WHERE trans_id  = ?
          ORDER BY position|;

      $items_sth = prepare_query($form, $dbh, $items_query);
    }

    foreach my $ap (@{ $form->{AP} }) {
      do_statement($form, $items_sth, $items_query, $ap->{id});
      $ap->{item_ids} = $dbh->selectcol_arrayref($items_sth);
      $ap->{item_ids} = undef if !@{$ap->{item_ids}};
    }
    $items_sth->finish();
  }

  $main::lxdebug->leave_sub();
}

sub get_transdate {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = SL::DB->client->dbh;

  my $query =
    "SELECT COALESCE(" .
    "  (SELECT transdate FROM ap WHERE id = " .
    "    (SELECT MAX(id) FROM ap) LIMIT 1), " .
    "  current_date)";
  ($form->{transdate}) = $dbh->selectrow_array($query);

  $main::lxdebug->leave_sub();
}

sub _delete_payments {
  $main::lxdebug->enter_sub();

  my ($self, $form, $dbh) = @_;

  my @delete_acc_trans_ids;

  # Delete old payment entries from acc_trans.
  my $query =
    qq|SELECT acc_trans_id
       FROM acc_trans
       WHERE (trans_id = ?) AND fx_transaction

       UNION

       SELECT at.acc_trans_id
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?) AND (c.link LIKE '%AP_paid%')|;
  push @delete_acc_trans_ids, selectall_array_query($form, $dbh, $query, conv_i($form->{id}), conv_i($form->{id}));

  $query =
    qq|SELECT at.acc_trans_id
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?)
         AND ((c.link = 'AP') OR (c.link LIKE '%:AP') OR (c.link LIKE 'AP:%'))
       ORDER BY at.acc_trans_id
       OFFSET 1|;
  push @delete_acc_trans_ids, selectall_array_query($form, $dbh, $query, conv_i($form->{id}));

  if (@delete_acc_trans_ids) {
    $query = qq|DELETE FROM acc_trans WHERE acc_trans_id IN (| . join(", ", @delete_acc_trans_ids) . qq|)|;
    do_query($form, $dbh, $query);
  }

  $main::lxdebug->leave_sub();
}

sub post_payment {
  my ($self, $myconfig, $form, $locale) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_post_payment, $self, $myconfig, $form, $locale);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _post_payment {
  my ($self, $myconfig, $form, $locale) = @_;

  my $dbh = SL::DB->client->dbh;

  my (%payments, $old_form, $row, $item, $query, %keep_vars);

  $old_form = save_form();

  $query = <<SQL;
    SELECT at.acc_trans_id, at.amount, at.cleared, c.accno
    FROM acc_trans at
    LEFT JOIN chart c ON (at.chart_id = c.id)
    WHERE (at.trans_id = ?)
SQL

  my %already_cleared = selectall_as_map($form, $dbh, $query, 'acc_trans_id', [ qw(amount cleared accno) ], $form->{id});

  # Delete all entries in acc_trans from prior payments.
  if (SL::DB::Default->get->payments_changeable != 0) {
    $self->_delete_payments($form, $dbh);
  }

  # Save the new payments the user made before cleaning up $form.
  my $payments_re = '^datepaid_\d+$|^gldate_\d+$|^acc_trans_id_\d+$|^memo_\d+$|^source_\d+$|^exchangerate_\d+$|^paid_\d+$|^paid_project_id_\d+$|^AP_paid_\d+$|^paidaccounts$';
  map { $payments{$_} = $form->{$_} } grep m/$payments_re/, keys %{ $form };

  # Clean up $form so that old content won't tamper the results.
  %keep_vars = map { $_, 1 } qw(login password id);
  map { delete $form->{$_} unless $keep_vars{$_} } keys %{ $form };

  # Retrieve the invoice from the database.
  $form->create_links('AP', $myconfig, 'vendor', $dbh);

  # Restore the payment options from the user input.
  map { $form->{$_} = $payments{$_} } keys %payments;

  # Set up the content of $form in the way that AR::post_transaction() expects.

  $self->setup_form($form, 1);

  $form->{exchangerate}    = $form->format_amount($myconfig, $form->{exchangerate});
  $form->{defaultcurrency} = $form->get_default_currency($myconfig);

  # Get the AP accno.
  $query =
    qq|SELECT c.id
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?)
         AND ((c.link = 'AP') OR (c.link LIKE '%:AP') OR (c.link LIKE 'AP:%'))
       ORDER BY at.acc_trans_id
       LIMIT 1|;

  ($form->{AP_chart_id}) = selectfirst_array_query($form, $dbh, $query, conv_i($form->{id}));

  # Post the new payments.
  $self->post_transaction($myconfig, $form, $dbh, payments_only => 1, already_cleared => \%already_cleared);

  restore_form($old_form);

  return 1;
}

sub setup_form {
  $main::lxdebug->enter_sub();

  my ($self, $form, $for_post_payments) = @_;

  my ($exchangerate, $i, $j, $k, $key, $akey, $ref, $index, $taxamount, $totalamount, $totaltax, $totalwithholding, $withholdingrate,
      $tax, $diff);

  # forex
  $form->{forex} = $form->{exchangerate};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  foreach $key (keys %{ $form->{AP_links} }) {
    foreach $ref (@{ $form->{AP_links}{$key} }) {
      if ($key eq "AP_paid") {
        $form->{"select$key"} .= "<option value=\"$ref->{accno}\">$ref->{accno}--$ref->{description}</option>\n";
      } else {
        $form->{"select$key"} .= "<option value=\"$ref->{accno}--$ref->{tax_id}\">$ref->{accno}--$ref->{description}</option>\n";
      }
    }

    $form->{$key} = $form->{"select$key"};

    $j = 0;
    $k = 0;

    # if there is a value we have an old entry
    next unless $form->{acc_trans}{$key};

    # do not use old entries for payments. They come from the form
    # even if they are not changeable (then they are in hiddens)
    next if $for_post_payments && $key eq "AP_paid";

    for $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {

      if ($key eq "AP_paid") {
        $j++;
        $form->{"AP_paid_$j"}         = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
        $form->{"acc_trans_id_$j"}    = $form->{acc_trans}{$key}->[$i - 1]->{acc_trans_id};
        $form->{"paid_$j"}            = $form->{acc_trans}{$key}->[$i - 1]->{amount};
        $form->{"datepaid_$j"}        = $form->{acc_trans}{$key}->[$i - 1]->{transdate};
        $form->{"gldate_$j"}          = $form->{acc_trans}{$key}->[$i - 1]->{gldate};
        $form->{"source_$j"}          = $form->{acc_trans}{$key}->[$i - 1]->{source};
        $form->{"memo_$j"}            = $form->{acc_trans}{$key}->[$i - 1]->{memo};

        $form->{"exchangerate_$i"}    = $form->{acc_trans}{$key}->[$i - 1]->{exchangerate};
        $form->{"forex_$j"}           = $form->{"exchangerate_$i"};
        $form->{"AP_paid_$j"}         = $form->{acc_trans}{$key}->[$i-1]->{accno};
        $form->{"paid_project_id_$j"} = $form->{acc_trans}{$key}->[$i - 1]->{project_id};
        $form->{"defaultcurrency_paid_$j"} = $form->{acc_trans}{$key}->[$i - 1]->{defaultcurrency_paid};
        $form->{"fx_transaction_$j"} = $form->{acc_trans}{$key}->[$i - 1]->{fx_transaction};
        $form->{paidaccounts}++;

      } else {
        $akey = $key;
        $akey =~ s/AP_//;

        if (($key eq "AP_tax") || ($key eq "AR_tax")) {
          $form->{"${key}_$form->{acc_trans}{$key}->[$i-1]->{accno}"}  = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
          $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} = $form->round_amount($form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate, 2);

          if ($form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"} > 0) {
            $totaltax += $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
          } else {
            $totalwithholding += $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
            $withholdingrate  += $form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"};
          }

          $index                 = $form->{acc_trans}{$key}->[$i - 1]->{index};
          $form->{"tax_$index"}  = $form->round_amount($form->{acc_trans}{$key}->[$i - 1]->{amount} * -1 / $exchangerate, 2);
          $totaltax             += $form->{"tax_$index"};

        } else {
          $k++;
          $form->{"${akey}_$k"} = $form->round_amount($form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate, 2);

          if ($akey eq 'amount') {
            $form->{rowcount}++;
            $form->{"${akey}_$i"} *= -1;
            $totalamount          += $form->{"${akey}_$i"};
            $form->{taxrate}       = $form->{acc_trans}{$key}->[$i - 1]->{rate};

            $form->{"projectnumber_$k"}    = "$form->{acc_trans}{$key}->[$i-1]->{projectnumber}";
            $form->{"oldprojectnumber_$k"} = $form->{"projectnumber_$k"};
            $form->{"project_id_$k"}       = "$form->{acc_trans}{$key}->[$i-1]->{project_id}";
            $form->{"${key}_chart_id_$k"}  = $form->{acc_trans}{$key}->[$i-1]->{chart_id};
            $form->{"taxchart_$k"} = $form->{acc_trans}{$key}->[$i-1]->{id}    . "--" . $form->{acc_trans}{$key}->[$i-1]->{rate};
          }
        }
      }
    }
  }

  $form->{paidaccounts} = 1            if not defined $form->{paidaccounts};

  if ($form->{taxincluded} && $form->{taxrate} && $totalamount) {
    # add tax to amounts and invtotal
    for $i (1 .. $form->{rowcount}) {
      $taxamount            = ($totaltax + $totalwithholding) * $form->{"amount_$i"} / $totalamount;
      $tax                  = $form->round_amount($taxamount, 2);
      $diff                += ($taxamount - $tax);
      $form->{"amount_$i"} += $form->{"tax_$i"};
    }

    $form->{amount_1} += $form->round_amount($diff, 2);
  }

  $taxamount        = $form->round_amount($taxamount, 2);
  $form->{invtotal} = $totalamount + $totaltax;

  $main::lxdebug->leave_sub();
}

sub storno {
  my ($self, $form, $myconfig, $id) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_storno, $self, $form, $myconfig, $id);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _storno {
  my ($self, $form, $myconfig, $id) = @_;

  my ($query, $new_id, $storno_row, $acc_trans_rows);
  my $dbh = SL::DB->client->dbh;

  $query = qq|SELECT nextval('glid')|;
  ($new_id) = selectrow_query($form, $dbh, $query);

  $query = qq|SELECT * FROM ap WHERE id = ?|;
  $storno_row = selectfirst_hashref_query($form, $dbh, $query, $id);

  $storno_row->{id}         = $new_id;
  $storno_row->{storno_id}  = $id;
  $storno_row->{storno}     = 't';
  $storno_row->{invnumber}  = 'Storno-' . $storno_row->{invnumber};
  $storno_row->{amount}    *= -1;
  $storno_row->{netamount} *= -1;
  $storno_row->{paid}       = $storno_row->{amount};

  delete @$storno_row{qw(itime mtime gldate)};

  $query = sprintf 'INSERT INTO ap (%s) VALUES (%s)', join(', ', keys %$storno_row), join(', ', map '?', values %$storno_row);
  do_query($form, $dbh, $query, (values %$storno_row));

  $query = qq|UPDATE ap SET paid = amount + paid, storno = 't' WHERE id = ?|;
  do_query($form, $dbh, $query, $id);

  $form->new_lastmtime('ap') if $id == $form->{id};

  # now copy acc_trans entries
  $query = qq|SELECT a.*, c.link FROM acc_trans a LEFT JOIN chart c ON a.chart_id = c.id WHERE a.trans_id = ? ORDER BY a.acc_trans_id|;
  my $rowref = selectall_hashref_query($form, $dbh, $query, $id);

  # kill all entries containing payments, which are the last 2n rows, of which the last has link =~ /paid/
  while ($rowref->[-1]{link} =~ /paid/) {
    splice(@$rowref, -2);
  }

  for my $row (@$rowref) {
    delete @$row{qw(itime mtime link acc_trans_id gldate)};
    $query = sprintf 'INSERT INTO acc_trans (%s) VALUES (%s)', join(', ', keys %$row), join(', ', map '?', values %$row);
    $row->{trans_id}   = $new_id;
    $row->{amount}    *= -1;
    do_query($form, $dbh, $query, (values %$row));
  }

  map { IO->set_datepaid(table => 'ap', id => $_, dbh => $dbh) } ($id, $new_id);

  if ($form->{workflow_email_journal_id}) {
    my $ap_transaction_storno = SL::DB::PurchaseInvoice->new(id => $new_id)->load;
    my $email_journal = SL::DB::EmailJournal->new(
      id => delete $form->{workflow_email_journal_id}
    )->load;
    $email_journal->link_to_record_with_attachment(
      $ap_transaction_storno,
      delete $form->{workflow_email_attachment_id}
    );
    $form->{callback} = delete $form->{workflow_email_callback};
  }

  $form->{storno_id} = $id;
  return 1;
}

1;
