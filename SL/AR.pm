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
# Accounts Receivable module backend routines
#
#======================================================================

package AR;

use Data::Dumper;
use SL::DATEV qw(:CONSTANTS);
use SL::DBUtils;
use SL::DB::Draft;
use SL::IO;
use SL::MoreCommon;
use SL::DB::Default;
use SL::DB::Invoice;
use SL::DB::EmailJournal;
use SL::DB::ValidityToken;
use SL::TransNumber;
use SL::Util qw(trim);
use SL::DB;

use strict;

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
      scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST(),
      token => $form->{form_validity_token},
    );

    die $::locale->text('The form is not valid anymore.') if !$validity_token;
  }

  my $payments_only = $params{payments_only};

  my ($query, $sth, $null, $taxrate, $amount, $tax);
  my $exchangerate = 0;
  my $i;
  $form->{script}      = 'ar.pl' unless $form->{script};

  my @values;

  my $dbh = $provided_dbh || SL::DB->client->dbh;

  # if we have an id delete old records else make one
  if (!$payments_only) {
    if ($form->{id}) {
      # delete detail records
      $query = qq|DELETE FROM acc_trans WHERE trans_id = ?|;
      do_query($form, $dbh, $query, $form->{id});

    } else {
      $query = qq|SELECT nextval('glid')|;
      ($form->{id}) = selectrow_query($form, $dbh, $query);
      $query = qq|INSERT INTO ar (id, invnumber, employee_id, currency_id, taxzone_id) VALUES (?, 'dummy', ?, (SELECT id FROM currencies WHERE name=?), (SELECT taxzone_id FROM customer WHERE id = ?))|;
      do_query($form, $dbh, $query, $form->{id}, $form->{employee_id}, $form->{currency}, $form->{customer_id});
      if (!$form->{invnumber}) {
        my $trans_number   = SL::TransNumber->new(type => 'invoice', dbh => $dbh, number => $form->{partnumber}, id => $form->{id});
        $form->{invnumber} = $trans_number->create_unique;
      }
    }
  }

  $form->{defaultcurrency} = $form->get_default_currency($myconfig);
  # check default or record exchangerate
  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate         = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'buy');
    $form->{exchangerate} = $form->parse_amount($myconfig, $form->{exchangerate}, 5);

    # if default exchangerate is not defined, define one
    unless ($exchangerate) {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, $form->{exchangerate}, 0);
      # delete records exchangerate -> if user sets new invdate for record
      $query = qq|UPDATE ar set exchangerate = NULL where id = ?|;
      do_query($form, $dbh, $query, $form->{"id"});
    }
    # update record exchangerate, if the default is set and differs from current
    if ($exchangerate && ($form->{exchangerate} != $exchangerate)) {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate},
                                 $form->{exchangerate}, 0,  $form->{id}, 'ar');
    }
  }

  # get the charts selected
  $form->{AR_amounts}{"amount_$_"} = $form->{"AR_amount_chart_id_$_"} for (1 .. $form->{rowcount});

  $form->{tax}       = 0; # is this still needed?

  # main calculation of rowcount loop inside Form method, amount_$i and tax_$i get formatted
  $form->{taxincluded} = 0 unless $form->{taxincluded};
  ($form->{netamount},$form->{total_tax},$form->{amount}) = $form->calculate_arap('sell', $form->{taxincluded}, $form->{exchangerate});

  # adjust paidaccounts if there is no date in the last row
  # this does not apply to stornos, where the paid field is set manually
  unless ($form->{storno}) {
    $form->{paidaccounts}-- unless $form->{"datepaid_$form->{paidaccounts}"};
    $form->{paid} = 0;

    # add payments
    for $i (1 .. $form->{paidaccounts}) {
      $form->{"paid_$i"} = $form->round_amount($form->parse_amount($myconfig, $form->{"paid_$i"}), 2);
      $form->{paid}     += $form->{"paid_$i"};
      $form->{datepaid}  = $form->{"datepaid_$i"};
    }

  }
  $form->{paid}   = $form->round_amount($form->{paid} * ($form->{exchangerate} || 1), 2);

  $form->get_employee($dbh) unless $form->{employee_id};



  # amount for AR account
  $form->{receivables} = $form->round_amount($form->{amount}, 2) * -1;

  if (!$payments_only) {
    $query =
      qq|UPDATE ar set
           invnumber = ?, ordnumber = ?, transdate = ?, customer_id = ?,
           taxincluded = ?, amount = ?, duedate = ?, deliverydate = ?, tax_point = ?, paid = ?,
           currency_id = (SELECT id FROM currencies WHERE name = ?),
           netamount = ?, notes = ?, department_id = ?,
           employee_id = ?, storno = ?, storno_id = ?, globalproject_id = ?,
           direct_debit = ?, transaction_description = ?
         WHERE id = ?|;
    my @values = ($form->{invnumber}, $form->{ordnumber}, conv_date($form->{transdate}), conv_i($form->{customer_id}), $form->{taxincluded} ? 't' : 'f', $form->{amount},
                  conv_date($form->{duedate}), conv_date($form->{deliverydate}), conv_date($form->{tax_point}), $form->{paid},
                  $form->{currency},
                  $form->{netamount}, $form->{notes}, conv_i($form->{department_id}),
                  conv_i($form->{employee_id}), $form->{storno} ? 't' : 'f', $form->{storno_id},
                  conv_i($form->{globalproject_id}), $form->{direct_debit} ? 't' : 'f', $form->{transaction_description},
                  conv_i($form->{id}));
    do_query($form, $dbh, $query, @values);

    # add individual transactions for AR, amount and taxes
    for $i (1 .. $form->{rowcount}) {
      if ($form->{"amount_$i"} != 0) {
        my $project_id = conv_i($form->{"project_id_$i"});

        # insert detail records in acc_trans
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, taxkey, tax_id, chart_link)
                     VALUES (?, ?, ?, ?, ?, ?, ?, (SELECT c.link FROM chart c WHERE c.id = ?))|;
        @values = (conv_i($form->{id}), $form->{AR_amounts}{"amount_$i"}, conv_i($form->{"amount_$i"}), conv_date($form->{transdate}), $project_id,
                   conv_i($form->{"taxkey_$i"}), conv_i($form->{"tax_id_$i"}), $form->{AR_amounts}{"amount_$i"});
        do_query($form, $dbh, $query, @values);

        if ($form->{"tax_$i"} != 0) {
          # insert detail records in acc_trans
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, taxkey, tax_id, chart_link)
                       VALUES (?, (SELECT c.id FROM chart c WHERE c.accno = ?), ?, ?, ?, ?, ?, (SELECT c.link FROM chart c WHERE c.accno = ?))|;
          @values = (conv_i($form->{id}), $form->{AR_amounts}{"tax_$i"}, conv_i($form->{"tax_$i"}), conv_date($form->{transdate}), $project_id,
                     conv_i($form->{"taxkey_$i"}), conv_i($form->{"tax_id_$i"}), $form->{AR_amounts}{"tax_$i"});
          do_query($form, $dbh, $query, @values);
        }
      }
    }

    # add recievables
    $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, taxkey, tax_id, chart_link)
                 VALUES (?, ?, ?, ?, (SELECT taxkey_id FROM chart WHERE id = ?),
                 (SELECT tax_id
                  FROM taxkeys
                  WHERE chart_id = ?
                  AND startdate <= ?
                  ORDER BY startdate DESC LIMIT 1),
                 (SELECT c.link FROM chart c WHERE c.id = ?))|;
    @values = (conv_i($form->{id}), $form->{AR_chart_id}, conv_i($form->{receivables}), conv_date($form->{transdate}),
                $form->{AR_chart_id}, $form->{AR_chart_id}, conv_date($form->{transdate}), $form->{AR_chart_id});
    do_query($form, $dbh, $query, @values);

  } else {
    # Record paid amount.
    $query = qq|UPDATE ar SET paid = ?, datepaid = ? WHERE id = ?|;
    do_query($form, $dbh, $query,  $form->{paid}, $form->{paid} ? conv_date($form->{datepaid}) : undef, conv_i($form->{id}));
  }

  $form->new_lastmtime('ar');

  my %already_cleared = %{ $params{already_cleared} // {} };

  # add paid transactions
  for my $i (1 .. $form->{paidaccounts}) {

    if ($form->{"acc_trans_id_$i"} && $payments_only && (SL::DB::Default->get->payments_changeable == 0)) {
      next;
    }

    if ($form->{"paid_$i"} != 0) {
      my $project_id = conv_i($form->{"paid_project_id_$i"});

      $form->{"AR_paid_$i"} =~ s/\"//g;
      ($form->{AR}{"paid_$i"}) = split(/--/, $form->{"AR_paid_$i"});
      $form->{"datepaid_$i"} = $form->{transdate}
        unless ($form->{"datepaid_$i"});

      $form->{"exchangerate_$i"} = ($form->{currency} eq $form->{defaultcurrency}) ? 1 :
        ( $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy') ||
          $form->parse_amount($myconfig, $form->{"exchangerate_$i"}) );

      # if there is no amount and invtotal is zero there is no exchangerate
      $form->{exchangerate} = $form->{"exchangerate_$i"}
        if ($form->{amount} == 0 && $form->{netamount} == 0);

      my $new_cleared = !$form->{"acc_trans_id_$i"}                                                       ? 'f'
                      : !$already_cleared{$form->{"acc_trans_id_$i"}}                                     ? 'f'
                      : $already_cleared{$form->{"acc_trans_id_$i"}}->{amount} != $form->{"paid_$i"} * -1 ? 'f'
                      : $already_cleared{$form->{"acc_trans_id_$i"}}->{accno}  != $form->{AR}{"paid_$i"}  ? 'f'
                      : $already_cleared{$form->{"acc_trans_id_$i"}}->{cleared}                           ? 't'
                      :                                                                                     'f';

      # receivables amount
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);

      if ($amount != 0) {
        # add receivable
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, cleared, taxkey, tax_id, chart_link)
                     VALUES (?, ?, ?, ?, ?, ?, (SELECT taxkey_id FROM chart WHERE id = ?),
                     (SELECT tax_id
                      FROM taxkeys
                      WHERE chart_id = ?
                      AND startdate <= ?
                      ORDER BY startdate DESC LIMIT 1),
                     (SELECT c.link FROM chart c WHERE c.id = ?))|;
        @values = (conv_i($form->{id}), $form->{AR_chart_id}, $amount, conv_date($form->{"datepaid_$i"}), $project_id, $new_cleared,
                   $form->{AR_chart_id}, $form->{AR_chart_id}, conv_date($form->{"datepaid_$i"}), $form->{AR_chart_id});

        do_query($form, $dbh, $query, @values);
      }

      if ($form->{"paid_$i"} != 0) {
        # add payment
        my $project_id = conv_i($form->{"paid_project_id_$i"});
        my $gldate = (conv_date($form->{"gldate_$i"}))? conv_date($form->{"gldate_$i"}) : conv_date($form->current_date($myconfig));
        $amount = $form->{"paid_$i"} * -1;
        $query  = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, gldate, source, memo, project_id, cleared, taxkey, tax_id, chart_link)
                     VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?, ?, ?, ?, (SELECT taxkey_id FROM chart WHERE accno = ?),
                     (SELECT tax_id
                      FROM taxkeys
                      WHERE chart_id= (SELECT id
                                       FROM chart
                                       WHERE accno = ?)
                      AND startdate <= ?
                      ORDER BY startdate DESC LIMIT 1),
                     (SELECT c.link FROM chart c WHERE c.accno = ?))|;
        @values = (conv_i($form->{id}), $form->{AR}{"paid_$i"}, $amount, conv_date($form->{"datepaid_$i"}), $gldate, $form->{"source_$i"}, $form->{"memo_$i"}, $project_id, $new_cleared, $form->{AR}{"paid_$i"},
                    $form->{AR}{"paid_$i"}, conv_date($form->{"datepaid_$i"}), $form->{AR}{"paid_$i"});
        do_query($form, $dbh, $query, @values);

        # exchangerate difference for payment
        $amount = $form->round_amount( $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) * -1, 2);

        if ($amount != 0) {
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, fx_transaction, cleared, project_id, taxkey, tax_id, chart_link)
                       VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, 't', 'f', ?, (SELECT taxkey_id FROM chart WHERE accno = ?),
                       (SELECT tax_id
                        FROM taxkeys
                        WHERE chart_id= (SELECT id
                                         FROM chart
                                         WHERE accno = ?)
                        AND startdate <= ?
                        ORDER BY startdate DESC LIMIT 1),
                       (SELECT c.link FROM chart c WHERE c.accno = ?))|;
          @values = (conv_i($form->{id}), $form->{AR}{"paid_$i"}, $amount, conv_date($form->{"datepaid_$i"}), $project_id, $form->{AR}{"paid_$i"},
                    $form->{AR}{"paid_$i"}, conv_date($form->{"datepaid_$i"}), $form->{AR}{"paid_$i"});
          do_query($form, $dbh, $query, @values);
        }

        # exchangerate gain/loss
        $amount = $form->round_amount( $form->{"paid_$i"} * ($form->{exchangerate} - $form->{"exchangerate_$i"}) * -1, 2);

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
          my $accno = ($amount > 0) ? $form->{fxgain_accno} : $form->{fxloss_accno};
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, fx_transaction, cleared, project_id, taxkey, tax_id, chart_link)
                       VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, 't', 'f', ?, (SELECT taxkey_id FROM chart WHERE accno = ?),
                       (SELECT tax_id
                        FROM taxkeys
                        WHERE chart_id= (SELECT id
                                         FROM chart
                                         WHERE accno = ?)
                        AND startdate <= ?
                        ORDER BY startdate DESC LIMIT 1),
                       (SELECT c.link FROM chart c WHERE c.accno = ?))|;
          @values = (conv_i($form->{id}), $accno, $amount, conv_date($form->{"datepaid_$i"}), $project_id, $accno, $accno, conv_date($form->{"datepaid_$i"}), $accno);
          do_query($form, $dbh, $query, @values);
        }
      }

      # update exchangerate record
      $form->update_exchangerate($dbh, $form->{currency}, $form->{"datepaid_$i"}, $form->{"exchangerate_$i"}, 0)
        if ($form->{currency} ne $form->{defaultcurrency}) && !$form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy');
    }
  }

  IO->set_datepaid(table => 'ar', id => $form->{id}, dbh => $dbh);

  if ($form->{draft_id}) {
    SL::DB::Manager::Draft->delete_all(where => [ id => delete($form->{draft_id}) ]);
  }

  # safety check datev export
  if ($::instance_conf->get_datev_check_on_ar_transaction) {
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
       WHERE (trans_id = ?) AND (c.link LIKE '%AR_paid%')|;
  push @delete_acc_trans_ids, selectall_array_query($form, $dbh, $query, conv_i($form->{id}), conv_i($form->{id}));

  $query =
    qq|SELECT at.acc_trans_id
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?)
         AND ((c.link = 'AR') OR (c.link LIKE '%:AR') OR (c.link LIKE 'AR:%'))
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
  my $payments_re = '^datepaid_\d+$|^gldate_\d+$|^acc_trans_id_\d+$|^memo_\d+$|^source_\d+$|^exchangerate_\d+$|^paid_\d+$|^paid_project_id_\d+$|^AR_paid_\d+$|^paidaccounts$';
  map { $payments{$_} = $form->{$_} } grep m/$payments_re/, keys %{ $form };

  # Clean up $form so that old content won't tamper the results.
  %keep_vars = map { $_, 1 } qw(login password id);
  map { delete $form->{$_} unless $keep_vars{$_} } keys %{ $form };

  # Retrieve the invoice from the database.
  $form->create_links('AR', $myconfig, 'customer', $dbh);

  # Restore the payment options from the user input.
  map { $form->{$_} = $payments{$_} } keys %payments;

  # Set up the content of $form in the way that AR::post_transaction() expects.

  $self->setup_form($form, 1);

  $form->{exchangerate}    = $form->format_amount($myconfig, $form->{exchangerate});
  $form->{defaultcurrency} = $form->get_default_currency($myconfig);

  # Get the AR chart ID (which is normally done by Form::create_links()).
  $query =
    qq|SELECT c.id
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?)
         AND ((c.link = 'AR') OR (c.link LIKE '%:AR') OR (c.link LIKE 'AR:%'))
       ORDER BY at.acc_trans_id
       LIMIT 1|;

  ($form->{AR_chart_id}) = selectfirst_array_query($form, $dbh, $query, conv_i($form->{id}));

  # Post the new payments.
  $self->post_transaction($myconfig, $form, $dbh, payments_only => 1, already_cleared => \%already_cleared);

  restore_form($old_form);

  return 1;
}

sub delete_transaction {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  SL::DB->client->with_transaction(sub {
    # acc_trans entries are deleted by database triggers.
    my $query = qq|DELETE FROM ar WHERE id = ?|;
    do_query($form, SL::DB->client->dbh, $query, $form->{id});
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();

  return 1;
}

sub ar_transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  my @values;

  my $query =
    qq|SELECT DISTINCT a.id, a.invnumber, a.ordnumber, a.cusordnumber, a.transdate, | .
    qq|  a.donumber, a.deliverydate, | .
    qq|  a.duedate, a.netamount, a.amount, a.paid, | .
    qq|  a.invoice, a.datepaid, a.notes, a.shipvia, | .
    qq|  a.shippingpoint, a.storno, a.storno_id, a.globalproject_id, | .
    qq|  a.marge_total, a.marge_percent, | .
    qq|  a.transaction_description, a.direct_debit, | .
    qq|  a.type, | .
    qq|  pr.projectnumber AS globalprojectnumber, | .
    qq|  c.name, c.customernumber, c.country, c.ustid, b.description as customertype, | .
    qq|  c.id as customer_id, c.dunning_lock as customer_dunning_lock,| .
    qq|  e.name AS employee, | .
    qq|  e2.name AS salesman, | .
    qq|  dc.dunning_description, | .
    qq|  tz.description AS taxzone, | .
    qq|  pt.description AS payment_terms, | .
    qq|  d.description AS department, | .
    qq|  s.shiptoname, s.shiptodepartment_1, s.shiptodepartment_2, | .
    qq|  s.shiptostreet, s.shiptozipcode, s.shiptocity, s.shiptocountry, | .
    qq{  ( SELECT ch.accno || ' -- ' || ch.description
           FROM acc_trans at
           LEFT JOIN chart ch ON ch.id = at.chart_id
           WHERE ch.link ~ 'AR[[:>:]]'
            AND at.trans_id = a.id
            LIMIT 1
          ) AS charts } .
    qq|FROM ar a | .
    qq|JOIN customer c ON (a.customer_id = c.id) | .
    qq|LEFT JOIN contacts cp ON (a.cp_id = cp.cp_id) | .
    qq|LEFT JOIN employee e ON (a.employee_id = e.id) | .
    qq|LEFT JOIN employee e2 ON (a.salesman_id = e2.id) | .
    qq|LEFT JOIN dunning_config dc ON (a.dunning_config_id = dc.id) | .
    qq|LEFT JOIN project pr ON (a.globalproject_id = pr.id)| .
    qq|LEFT JOIN tax_zones tz ON (tz.id = a.taxzone_id)| .
    qq|LEFT JOIN payment_terms pt ON (pt.id = a.payment_id)| .
    qq|LEFT JOIN business b ON (b.id = c.business_id)| .
    qq|LEFT JOIN shipto s ON (
        (a.shipto_id = s.shipto_id) or
        (a.id = s.trans_id and s.module = 'AR')
       )| .
    qq|LEFT JOIN department d ON (d.id = a.department_id)|;

  my $where = "1 = 1";

  # Permissions:
  # - Always return invoices & AR transactions for projects the employee has "view invoices" permissions for, no matter what the other rules say.
  # - Exclude AR transactions if no permissions for them exist.
  # - Limit to own invoices unless may edit all invoices or view invoices is allowed.
  # - If may edit all or view invoices is allowed, allow filtering by employee/salesman.
  my (@permission_where, @permission_values);

  if ($::auth->assert('invoice_edit', 1) || $::auth->assert('sales_invoice_view', 1)) {
    if (!$::auth->assert('show_ar_transactions', 1) ) {
      push @permission_where, "NOT invoice = 'f'";  # remove ar transactions from Sales -> Reports -> Invoices
    }

    if (!$::auth->assert('sales_all_edit', 1) && !$::auth->assert('sales_invoice_view', 1)) {
      # only show own invoices
      push @permission_where,  "a.employee_id = ?";
      push @permission_values, SL::DB::Manager::Employee->current->id;

    } else {
      if ($form->{employee_id}) {
        push @permission_where,  "a.employee_id = ?";
        push @permission_values, conv_i($form->{employee_id});
      }
      if ($form->{salesman_id}) {
        push @permission_where,  "a.salesman_id = ?";
        push @permission_values, conv_i($form->{salesman_id});
      }
    }
  }

  if (@permission_where || (!$::auth->assert('invoice_edit', 1) && !$::auth->assert('sales_invoice_view', 1))) {
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

  if ($form->{customer}) {
    $where .= " AND c.name ILIKE ?";
    push(@values, like($form->{customer}));
  }
  if ($form->{"cp_name"}) {
    $where .= " AND (cp.cp_name ILIKE ? OR cp.cp_givenname ILIKE ?)";
    push(@values, (like($form->{"cp_name"}))x2);
  }
  if ($form->{business_id}) {
    my $business_id = $form->{business_id};
    $where .= " AND c.business_id = ?";
    push(@values, $business_id);
  }
  if ($form->{taxzone_id}) {
    $where .= " AND a.taxzone_id = ?";
    push(@values, $form->{taxzone_id});
  }
  if ($form->{department_id}) {
    $where .= " AND a.department_id = ?";
    push(@values, $form->{department_id});
  }
  if ($form->{payment_id}) {
    $where .= " AND a.payment_id = ?";
    push(@values, $form->{payment_id});
  }
  foreach my $column (qw(invnumber ordnumber cusordnumber notes transaction_description shipvia shippingpoint)) {
    if ($form->{$column}) {
      $where .= " AND a.$column ILIKE ?";
      push(@values, like($form->{$column}));
    }
  }
  if ($form->{"project_id"}) {
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
  if ($form->{open} || $form->{closed}) {
    unless ($form->{open} && $form->{closed}) {
      $where .= " AND a.amount <> a.paid" if ($form->{open});
      $where .= " AND a.amount = a.paid"  if ($form->{closed});
    }
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

  if ($form->{show_not_mailed}) {
    $where .= <<SQL;
      AND NOT EXISTS (
        SELECT rl.to_id
        FROM record_links rl
        WHERE (rl.from_id = a.id)
          AND (rl.to_table = 'email_journal')
        LIMIT 1
      )
SQL
  }

  if ($form->{show_marked_as_closed}) {
    $query .= '
      LEFT JOIN (
              SELECT SUM(acc_trans.amount) AS amount, trans_id
              FROM acc_trans
              LEFT JOIN chart ON chart.id = chart_id
              WHERE chart.link ILIKE ?
              GROUP BY trans_id
      ) AS paid_difference ON (paid_difference.trans_id = a.id)
    ';
    unshift @values, '%AR_paid%';
    $where .= ' AND COALESCE(paid_difference.amount, 0) + a.paid != 0';
  }

  if ($form->{shiptoname}) {
    $where .= " AND s.shiptoname ILIKE ?";
    push(@values, like($form->{shiptoname}));
  }
  if ($form->{shiptodepartment_1}) {
    $where .= " AND s.shiptodepartment_1 ILIKE ?";
    push(@values, like($form->{shiptodepartment_1}));
  }
  if ($form->{shiptodepartment_2}) {
    $where .= " AND s.shiptodepartment_2 ILIKE ?";
    push(@values, like($form->{shiptodepartment_2}));
  }
  if ($form->{shiptostreet}) {
    $where .= " AND s.shiptostreet ILIKE ?";
    push(@values, like($form->{shiptostreet}));
  }
  if ($form->{shiptozipcode}) {
    $where .= " AND s.shiptozipcode ILIKE ?";
    push(@values, like($form->{shiptozipcode}));
  }
  if ($form->{shiptocity}) {
    $where .= " AND s.shiptocity ILIKE ?";
    push(@values, like($form->{shiptocity}));
  }
  if ($form->{shiptocountry}) {
    $where .= " AND s.shiptocountry ILIKE ?";
    push(@values, like($form->{shiptocountry}));
  }

  my ($cvar_where, @cvar_values) = CVar->build_filter_query('module'         => 'CT',
                                                            'trans_id_field' => 'c.id',
                                                            'filter'         => $form,
                                                           );
  if ($cvar_where) {
    $where .= qq| AND ($cvar_where)|;
    push @values, @cvar_values;
  }

  my @a = qw(transdate invnumber name);
  push @a, "employee" if $form->{l_employee};
  my $sortdir   = !defined $form->{sortdir} ? 'ASC' : $form->{sortdir} ? 'ASC' : 'DESC';
  my $sortorder = join(', ', map { "$_ $sortdir" } @a);

  if (grep({ $_ eq $form->{sort} } qw(id transdate duedate invnumber ordnumber cusordnumber donumber deliverydate name datepaid employee shippingpoint shipvia transaction_description department taxzone))) {
    $sortorder = $form->{sort} . " $sortdir";
  }

  $query .= " WHERE $where ORDER BY $sortorder";

  my @result = selectall_hashref_query($form, $dbh, $query, @values);

  $form->{AR} = [ @result ];

  if ($form->{l_items} && scalar @{ $form->{AR} }) {
    my ($items_query, $items_sth);
    if ($form->{l_items}) {
      $items_query =
        qq|SELECT id
          FROM invoice
          WHERE trans_id  = ?
          ORDER BY position|;

      $items_sth = prepare_query($form, $dbh, $items_query);
    }

    foreach my $ar (@{ $form->{AR} }) {
      do_statement($form, $items_sth, $items_query, $ar->{id});
      $ar->{item_ids} = $dbh->selectcol_arrayref($items_sth);
      $ar->{item_ids} = undef if !@{$ar->{item_ids}};
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
    "  (SELECT transdate FROM ar WHERE id = " .
    "    (SELECT MAX(id) FROM ar) LIMIT 1), " .
    "  current_date)";
  ($form->{transdate}) = $dbh->selectrow_array($query);

  $main::lxdebug->leave_sub();
}

sub setup_form {
  $main::lxdebug->enter_sub();

  my ($self, $form, $for_post_payments) = @_;

  my ($exchangerate, $akey, $j, $k, $index, $taxamount, $totaltax, $taxrate, $diff, $totalwithholding, $withholdingrate,
      $totalamount, $tax);

  # forex
  $form->{forex} = $form->{exchangerate};
  $exchangerate  = $form->{exchangerate} ? $form->{exchangerate} : 1;

  # expected keys: AR, AR_paid, AR_tax, AR_amount
  foreach my $key (keys %{ $form->{AR_links} }) {
    $j = 0;
    $k = 0;

    # if there is a value we have an old entry
    next unless $form->{acc_trans}{$key};

    # do not use old entries for payments. They come from the form
    # even if they are not changeable (then they are in hiddens)
    next if $for_post_payments && $key eq "AR_paid";

    for my $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {
      if ($key eq "AR_paid") {
        $j++;
        $form->{"AR_paid_$j"} = $form->{acc_trans}{$key}->[$i-1]->{accno};

        $form->{"acc_trans_id_$j"}    = $form->{acc_trans}{$key}->[$i - 1]->{acc_trans_id};
        # reverse paid
        $form->{"paid_$j"}            = $form->{acc_trans}{$key}->[$i - 1]->{amount} * -1;
        $form->{"datepaid_$j"}        = $form->{acc_trans}{$key}->[$i - 1]->{transdate};
        $form->{"gldate_$j"}          = $form->{acc_trans}{$key}->[$i - 1]->{gldate};
        $form->{"source_$j"}          = $form->{acc_trans}{$key}->[$i - 1]->{source};
        $form->{"memo_$j"}            = $form->{acc_trans}{$key}->[$i - 1]->{memo};
        $form->{"forex_$j"}           = $form->{acc_trans}{$key}->[$i - 1]->{exchangerate};
        $form->{"exchangerate_$i"}    = $form->{"forex_$j"};
        $form->{"paid_project_id_$j"} = $form->{acc_trans}{$key}->[$i - 1]->{project_id};
        $form->{"defaultcurrency_paid_$j"} = $form->{acc_trans}{$key}->[$i - 1]->{defaultcurrency_paid};
        $form->{"fx_transaction_$j"}  = $form->{acc_trans}{$key}->[$i - 1]->{fx_transaction};
        $form->{paidaccounts}++;

      } else { # e.g. AR_amount, AR, AR_tax

        $akey = $key;
        $akey =~ s/AR_//; # e.g. tax, amount, AR, used to store form key tax_$i, amount_$i, ...

        if ($key eq "AR_tax" || $key eq "AP_tax") { # AR_tax
          $form->{"${key}_$form->{acc_trans}{$key}->[$i-1]->{accno}"}  = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
          # determine the rounded tax amounts for each account, e.g. tax_1776
          $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} = $form->round_amount($form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate, 2);

          # check e.g. $form->{1776_rate}, does this make sense for AR_tax charts? Is this ever valid? If it was, totaltax would be calculated twice
          if ($form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"} > 0) {
            $totaltax += $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
            $taxrate  += $form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"};

          } else {
            $totalwithholding += $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
            $withholdingrate  += $form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"};
          }

          $index                 = $form->{acc_trans}{$key}->[$i - 1]->{index};
          $form->{"tax_$index"}  = $form->round_amount($form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate, 2); # convert the tax_$i amounts
          # currently totaltax is the sum of rounded tax amounts, is this correct?
          $totaltax             += $form->{"tax_$index"};

        } else { # e.g. AR_amount, AR
          $k++;
          $form->{"${akey}_$k"} = $form->round_amount($form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate, 2);

          if ($akey eq 'amount') {
            $form->{rowcount}++;
            $totalamount += $form->{"${akey}_$i"};

            $form->{"oldprojectnumber_$k"} = $form->{acc_trans}{$key}->[$i-1]->{projectnumber};
            $form->{"projectnumber_$k"}    = $form->{acc_trans}{$key}->[$i-1]->{projectnumber};
            $form->{taxrate}               = $form->{acc_trans}{$key}->[$i - 1]->{rate};
            $form->{"project_id_$k"}       = $form->{acc_trans}{$key}->[$i-1]->{project_id};

            $form->{"${key}_chart_id_$k"} = $form->{acc_trans}{$key}->[$i-1]->{chart_id};
            $form->{"taxchart_$k"} = $form->{acc_trans}{$key}->[$i-1]->{id}    . "--" . $form->{acc_trans}{$key}->[$i-1]->{rate};
          }
        }
      }
    }
  }

  $form->{paidaccounts} = 1            if not defined $form->{paidaccounts};

  if ($form->{taxincluded} && $form->{taxrate} && $totalamount) {

    # add tax to amounts and invtotal
    for my $i (1 .. $form->{rowcount}) {
      $taxamount            = ($totaltax + $totalwithholding) * $form->{"amount_$i"} / $totalamount;
      $tax                  = $form->round_amount($taxamount, 2);
      $diff                += ($taxamount - $tax);
      $form->{"amount_$i"} += $form->{"tax_$i"};
    }
    $form->{amount_1} += $form->round_amount($diff, 2);
  }

  $taxamount   = $form->round_amount($taxamount, 2);
  $form->{tax} = $taxamount;

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

  $query = qq|SELECT * FROM ar WHERE id = ?|;
  $storno_row = selectfirst_hashref_query($form, $dbh, $query, $id);

  $storno_row->{id}         = $new_id;
  $storno_row->{storno_id}  = $id;
  $storno_row->{storno}     = 't';
  $storno_row->{invnumber}  = 'Storno-' . $storno_row->{invnumber};
  $storno_row->{amount}    *= -1;
  $storno_row->{netamount} *= -1;
  $storno_row->{paid}       = $storno_row->{amount};

  delete @$storno_row{qw(itime mtime)};

  $query = sprintf 'INSERT INTO ar (%s) VALUES (%s)', join(', ', keys %$storno_row), join(', ', map '?', values %$storno_row);
  do_query($form, $dbh, $query, (values %$storno_row));

  $query = qq|UPDATE ar SET paid = amount + paid, storno = 't' WHERE id = ?|;
  do_query($form, $dbh, $query, $id);

  $form->new_lastmtime('ar') if $id == $form->{id};

  # now copy acc_trans entries
  $query = qq|SELECT a.*, c.link FROM acc_trans a LEFT JOIN chart c ON a.chart_id = c.id WHERE a.trans_id = ? ORDER BY a.acc_trans_id|;
  my $rowref = selectall_hashref_query($form, $dbh, $query, $id);

  # kill all entries containing payments, which are the last 2n rows, of which the last has link =~ /paid/
  while ($rowref->[-1]{link} =~ /paid/) {
    splice(@$rowref, -2);
  }

  for my $row (@$rowref) {
    delete @$row{qw(itime mtime link acc_trans_id)};
    $query = sprintf 'INSERT INTO acc_trans (%s) VALUES (%s)', join(', ', keys %$row), join(', ', map '?', values %$row);
    $row->{trans_id}   = $new_id;
    $row->{amount}    *= -1;
    do_query($form, $dbh, $query, (values %$row));
  }

  map { IO->set_datepaid(table => 'ar', id => $_, dbh => $dbh) } ($id, $new_id);

  if ($form->{workflow_email_journal_id}) {
    my $ar_transaction_storno = SL::DB::Invoice->new(id => $new_id)->load;
    my $email_journal = SL::DB::EmailJournal->new(
      id => delete $form->{workflow_email_journal_id}
    )->load;
    $email_journal->link_to_record_with_attachment(
      $ar_transaction_storno,
      delete $form->{workflow_email_attachment_id}
    );
    $form->{callback} = delete $form->{workflow_email_callback};
  }

  $form->{storno_id} = $id;
  return 1;
}


1;
