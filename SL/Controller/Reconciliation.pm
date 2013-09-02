package SL::Controller::Reconciliation;

use strict;

use parent qw(SL::Controller::Base);

use SL::Locale::String;
use SL::JSON;
use SL::Controller::Helper::ParseFilter;
use SL::Helper::Flash;

use SL::DB::BankTransaction;
use SL::DB::BankAccount;
use SL::DB::AccTransaction;
use SL::DB::ReconciliationLink;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(cleared BANK_ACCOUNTS) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('_bank_account');

#
# actions
#

sub action_search {
  my ($self) = @_;

  $self->render('reconciliation/search',
                 label_sub => sub { t8('#1 - Account number #2, bank code #3, #4',
                                        $_[0]->name,
                                        $_[0]->bank,
                                        $_[0]->account_number,
                                        $_[0]->bank_code) });
}

sub action_reconciliation {
  my ($self) = @_;

  $self->_get_linked_transactions;

  $self->_get_balances;

  $self->render('reconciliation/form',
                title => t8('Reconciliation'),
                label_sub => sub { t8('#1 - Account number #2, bank code #3, #4',
                                        $_[0]->name,
                                        $_[0]->bank,
                                        $_[0]->account_number,
                                        $_[0]->bank_code) });
}

sub action_load_overview {
  my ($self) = @_;

  $self->_get_proposals;

  $self->_get_linked_transactions;

  $self->_get_balances;

  my $output = $self->render('reconciliation/tabs/overview', { output => 0 });
  my %result = ( html => $output );

  $self->render(\to_json(\%result), { type => 'json', process => 0 });
}

sub action_filter_overview {
  my ($self) = @_;

  $self->_get_linked_transactions;
  $self->_get_balances;

  my $output = $self->render('reconciliation/_linked_transactions', { output => 0 });
  my %result = ( html => $output,
                 absolut_bt_balance => $::form->format_amount(\%::myconfig, $self->{absolut_bt_balance}, 2),
                 absolut_bb_balance => $::form->format_amount(\%::myconfig, -1 * $self->{absolut_bb_balance}, 2),
                 bt_balance => $::form->format_amount(\%::myconfig, $self->{bt_balance}, 2),
                 bb_balance => $::form->format_amount(\%::myconfig, -1 * $self->{bb_balance}, 2)
                 );

  $self->render(\to_json(\%result), { type => 'json', process => 0 });
}

sub action_update_reconciliation_table {
  my ($self) = @_;

  my @errors = $self->_get_elements_and_validate();

  my $output = $self->render('reconciliation/assigning_table', { output => 0 },
                 bt_sum => $::form->format_amount(\%::myconfig, $self->{bt_sum}, 2),
                 bb_sum => $::form->format_amount(\%::myconfig, -1 * $self->{bb_sum}, 2),
                 show_button => !@errors
                 );

  my %result = ( html => $output );

  $self->render(\to_json(\%result), { type => 'json', process => 0 });
}

sub action_reconciliate {
  my ($self) = @_;

  #Check elements
  my @errors = $self->_get_elements_and_validate;

  if (@errors) {
    unshift(@errors, (t8('Could not reconciliate chosen elements!')));
    flash('error', @errors);
    $self->action_reconciliation;
    return;
  }

  $self->_reconciliate;

  $self->action_reconciliation;
}

sub action_delete_reconciliation {
  my ($self) = @_;

  my $rec_links = SL::DB::Manager::ReconciliationLink->get_all(where => [ rec_group => $::form->{rec_group} ]);

  foreach my $rec_link (@{ $rec_links }) {
    my $bank_transaction = SL::DB::Manager::BankTransaction->find_by( id           => $rec_link->bank_transaction_id );
    my $acc_transaction  = SL::DB::Manager::AccTransaction ->find_by( acc_trans_id => $rec_link->acc_trans_id        );

    $bank_transaction->cleared('0');
    $acc_transaction->cleared('0');

    $bank_transaction->save;
    $acc_transaction->save;

    $rec_link->delete;
  }

  $self->_get_linked_transactions;
  $self->_get_balances;

  my $output = $self->render('reconciliation/_linked_transactions', { output => 0 });
  my %result = ( html => $output,
                 absolut_bt_balance => $::form->format_amount(\%::myconfig, $self->{absolut_bt_balance}, 2),
                 absolut_bb_balance => $::form->format_amount(\%::myconfig, -1 * $self->{absolut_bb_balance}, 2),
                 bt_balance => $::form->format_amount(\%::myconfig, $self->{bt_balance}, 2),
                 bb_balance => $::form->format_amount(\%::myconfig, -1 * $self->{bb_balance}, 2)
                 );

  $self->render(\to_json(\%result), { type => 'json', process => 0 });
}

sub action_load_proposals {
  my ($self) = @_;

  $self->_get_proposals;

  my $output = $self->render('reconciliation/tabs/automatic', { output => 0 });
  my %result = ( html => $output );

  $self->render(\to_json(\%result), { type => 'json', process => 0 });
}

sub action_filter_proposals {
  my ($self) = @_;

  $self->_get_balances;
  $self->_get_proposals;

  my $output = $self->render('reconciliation/proposals', { output => 0 });
  my %result = ( html => $output,
                 absolut_bt_balance => $::form->format_amount(\%::myconfig, $self->{absolut_bt_balance}, 2),
                 absolut_bb_balance => $::form->format_amount(\%::myconfig, -1 * $self->{absolut_bb_balance}, 2),
                 bt_balance => $::form->format_amount(\%::myconfig, $self->{bt_balance}, 2),
                 bb_balance => $::form->format_amount(\%::myconfig, -1 * $self->{bb_balance}, 2)
                 );

  $self->render(\to_json(\%result), { type => 'json', process => 0 });
}

sub action_reconciliate_proposals {
  my ($self) = @_;

  my $counter = 0;

  foreach my $bt_id ( @{ $::form->{bt_ids} }) {
    my $rec_group = SL::DB::Manager::ReconciliationLink->get_new_rec_group();
    my $bank_transaction = SL::DB::Manager::BankTransaction->find_by(id => $bt_id);
    $bank_transaction->cleared('1');
    if ( $bank_transaction->isa('SL::DB::BankTransaction') ) {
      $bank_transaction->invoice_amount($bank_transaction->amount);
    }
    $bank_transaction->save;
    foreach my $acc_trans_id (@{ $::form->{proposal_list}->{$bt_id}->{BB} }) {
      SL::DB::ReconciliationLink->new(
        rec_group => $rec_group,
        bank_transaction_id => $bt_id,
        acc_trans_id => $acc_trans_id
      )->save;
      my $acc_trans = SL::DB::Manager::AccTransaction->find_by(acc_trans_id => $acc_trans_id);
      $acc_trans->cleared('1');
      $acc_trans->save;
    }
    $counter++;
  }

  flash('ok', t8('#1 proposal(s) saved.', $counter));

  $self->action_reconciliation;
}

#
# filters
#

sub check_auth {
  $::auth->assert('bank_transaction');
}

sub _bank_account {
  my ($self) = @_;
  $self->{bank_account} = SL::DB::Manager::BankAccount->find_by(id => $::form->{filter}->{"local_bank_account_id:number"});
}

#
# helpers
#

sub _get_proposals {
  my ($self) = @_;

  $self->_filter_to_where;

  my $bank_transactions = SL::DB::Manager::BankTransaction->get_all(where => [ @{ $self->{bt_where} }, cleared => '0' ]);

  my $check_sum;

  my @proposals;

  foreach my $bt (@{ $bank_transactions }) {
    $check_sum = $bt->amount;
    my $proposal;
    $proposal->{BT} = $bt;
    $proposal->{BB} = [];

    my $linked_records = SL::DB::Manager::RecordLink->get_all(where => [ from_table => 'bank_transactions', from_id => $bt->id ]);
    foreach my $linked_record (@{ $linked_records }) {
      my $invoice;
      if ($linked_record->to_table eq 'ar') {
        $invoice = SL::DB::Manager::Invoice->find_by(id => $linked_record->to_id);
        #find payments
        my $payments = SL::DB::Manager::AccTransaction->get_all(where => [ trans_id => $invoice->id, chart_link => { like => '%AR_paid%' }, transdate => $bt->transdate ]);
        foreach my $payment (@{ $payments }) {
          $check_sum += $payment->amount;
          push @{ $proposal->{BB} }, $payment;
        }
      }
      if ($linked_record->to_table eq 'ap') {
        $invoice = SL::DB::Manager::PurchaseInvoice->find_by(id => $linked_record->to_id);
        #find payments
        my $payments = SL::DB::Manager::AccTransaction->get_all(where => [ trans_id => $invoice->id, chart_link => { like => '%AP_paid%' }, transdate => $bt->transdate ]);
        foreach my $payment (@{ $payments }) {
          $check_sum += $payment->amount;
          push @{ $proposal->{BB} }, $payment;
        }
      }
    }

    #add proposal if something in acc_trans was found
    #otherwise try to find another entry in acc_trans and add it
    if (scalar @{ $proposal->{BB} } and !$check_sum) {
      push @proposals, $proposal;
    } elsif (!scalar @{ $proposal->{BB} }) {
      my $acc_transactions = SL::DB::Manager::AccTransaction->get_all(where => [ @{ $self->{bb_where} },
                                                                                 amount => -1 * $bt->amount,
                                                                                 cleared => '0',
                                                                                 or => [
                                                                                   and => [ 'ar.customer.account_number' => $bt->remote_account_number,
                                                                                            'ar.customer.bank_code'      => $bt->remote_bank_code, ],
                                                                                   and => [ 'ap.vendor.account_number' => $bt->remote_account_number,
                                                                                            'ap.vendor.bank_code'      => $bt->remote_bank_code, ],
                                                                                   'gl.storno' => '0' ]],
                                                                       with_objects => [ 'ar', 'ap', 'ar.customer', 'ap.vendor', 'gl' ]);
      if (scalar @{ $acc_transactions } == 1) {
        push @{ $proposal->{BB} }, @{ $acc_transactions }[0];
        push @proposals, $proposal;
      }
    }
  }

  $self->{PROPOSALS} = \@proposals;
}

sub _get_elements_and_validate {
  my ($self) = @_;

  my @errors;

  if ( not defined $::form->{bt_ids} ) {
    push @errors, t8('No bank account chosen!');
  }

  if ( not defined $::form->{bb_ids} ) {
    push @errors, t8('No transaction on chart bank chosen!');
  }

  if (!@errors) {
    if (scalar @{ $::form->{bt_ids} } > 1 and scalar @{ $::form->{bb_ids} } > 1) {
      push @errors, t8('No 1:n or n:1 relation');
    }
  }

  my @elements;
  my ($bt_sum, $bb_sum) = (0,0);

  foreach my $bt_id (@{ $::form->{bt_ids} }) {
    my $bt = SL::DB::Manager::BankTransaction->find_by(id => $bt_id);
    $bt->{type} = 'BT';
    $bt_sum += $bt->amount;
    push @elements, $bt;
  }

  foreach my $bb_id (@{ $::form->{bb_ids} }) {
    my $bb = SL::DB::Manager::AccTransaction->find_by(acc_trans_id => $bb_id);
    $bb->{type} = 'BB';
    $bb->{id} = $bb->acc_trans_id;
    $bb_sum += $bb->amount;
    push @elements, $bb;
  }

  if ($::form->round_amount($bt_sum + $bb_sum) != 0) {
    push @errors, t8('Out of balance!');
  }

  $self->{ELEMENTS} = \@elements;
  $self->{bt_sum} = $bt_sum;
  $self->{bb_sum} = $bb_sum;

  return @errors;
}

sub _reconciliate {
  my ($self) = @_;

  #1. Step: Set AccTrans and BankTransactions to 'cleared'
  foreach my $element (@{ $self->{ELEMENTS} }) {
    $element->cleared('1');
    $element->invoice_amount($element->amount) if $element->isa('SL::DB::BankTransaction');
    $element->save;
  }

  #2. Step: Insert entry in reconciliation_links
  my $rec_group = SL::DB::Manager::ReconciliationLink->get_new_rec_group();
  #There is either a 1:n relation or a n:1 relation
  if (scalar @{ $::form->{bt_ids} } == 1) {
    my $bt_id = @{ $::form->{bt_ids} }[0];
    foreach my $bb_id (@{ $::form->{bb_ids} }) {
      my $rec_link = SL::DB::ReconciliationLink->new(bank_transaction_id => $bt_id,
                                                     acc_trans_id        => $bb_id,
                                                     rec_group           => $rec_group);
      $rec_link->save;
    }
  } else {
    my $bb_id = @{ $::form->{bb_ids} }[0];
    foreach my $bt_id (@{ $::form->{bt_ids} }) {
      my $rec_link = SL::DB::ReconciliationLink->new(bank_transaction_id => $bt_id,
                                                     acc_trans_id        => $bb_id,
                                                     rec_group           => $rec_group);
      $rec_link->save;
    }
  }
}

sub _filter_to_where {
  my ($self) = @_;

  my %parse_filter = parse_filter($::form->{filter});
  my %filter = @{ $parse_filter{query} };

  my (@rl_where, @bt_where, @bb_where);
  @rl_where    = ('bank_transaction.local_bank_account_id' => $filter{local_bank_account_id});
  @bt_where = (local_bank_account_id => $filter{local_bank_account_id});
  @bb_where = (chart_id              => $self->{bank_account}->chart_id);

  if ($filter{fromdate} and $filter{todate}) {

    push @rl_where, (or => [ and => [ 'acc_tran.transdate'         => $filter{fromdate},
                                      'acc_tran.transdate'         => $filter{todate} ],
                             and => [ 'bank_transaction.transdate' => $filter{fromdate},
                                      'bank_transaction.transdate' => $filter{todate} ] ] );

    push @bt_where, (transdate                    => $filter{todate} );
    push @bt_where, (transdate                    => $filter{fromdate} );
    push @bb_where, (transdate                    => $filter{todate} );
    push @bb_where, (transdate                    => $filter{fromdate} );
  }

  if ($filter{fromdate} and not $filter{todate}) {
    push @rl_where, (or => [ 'acc_tran.transdate'         => $filter{fromdate},
                             'bank_transaction.transdate' => $filter{fromdate} ] );
    push @bt_where, (transdate                    => $filter{fromdate} );
    push @bb_where, (transdate                    => $filter{fromdate} );
  }

  if ($filter{todate} and not $filter{fromdate}) {
    push @rl_where, ( or => [ 'acc_tran.transdate'         => $filter{todate} ,
                              'bank_transaction.transdate' => $filter{todate} ] );
    push @bt_where, (transdate                    => $filter{todate} );
    push @bb_where, (transdate                    => $filter{todate} );
  }

  if ($filter{cleared}) {
    $filter{cleared} = $filter{cleared} eq 'FALSE' ? '0' : '1';
    push @rl_where, ('acc_tran.cleared'         => $filter{cleared} );

    push @bt_where, (cleared                    => $filter{cleared} );
    push @bb_where, (cleared                    => $filter{cleared} );
  }

  $self->{rl_where} = \@rl_where;
  $self->{bt_where} = \@bt_where;
  $self->{bb_where} = \@bb_where;
}

sub _get_linked_transactions {
  my ($self) = @_;

  $self->_filter_to_where;

  my (@where, @bt_where, @bb_where);
  @where    = (@{ $self->{rl_where} });
  @bt_where = (@{ $self->{bt_where} }, cleared => '0');
  @bb_where = (@{ $self->{bb_where} }, cleared => '0');

  my @rows;

  my $reconciliation_groups = SL::DB::Manager::ReconciliationLink->get_all(distinct => 1,
                                                                           select => ['rec_group'],
                                                                           where => \@where,
                                                                           with_objects => ['bank_transaction', 'acc_tran']);

  my $fromdate = $::locale->parse_date_to_object(\%::myconfig, $::form->{filter}->{fromdate_date__ge});
  my $todate   = $::locale->parse_date_to_object(\%::myconfig, $::form->{filter}->{todate_date__le});

  foreach my $rec_group (@{ $reconciliation_groups }) {
    my $linked_transactions = SL::DB::Manager::ReconciliationLink->get_all(where => [rec_group => $rec_group->rec_group], with_objects => ['bank_transaction', 'acc_tran']);
    my $line;
    my $first_transaction = shift @{ $linked_transactions };
    my $first_bt = $first_transaction->bank_transaction;
    my $first_bb = $first_transaction->acc_tran;

    if (defined $fromdate) {
      $first_bt->{class} = 'out_of_balance' if ( $first_bt->transdate lt $fromdate );
      $first_bb->{class} = 'out_of_balance' if ( $first_bb->transdate lt $fromdate );
    }
    if (defined $todate) {
      $first_bt->{class} = 'out_of_balance' if ( $first_bt->transdate gt $todate );
      $first_bb->{class} = 'out_of_balance' if ( $first_bb->transdate gt $todate );
    }
    $line->{BT} = [ $first_bt ];
    $line->{BB} = [ $first_bb ];
    $line->{rec_group} = $first_transaction->rec_group;
    $line->{type} = 'Link';

    #add the rest of transaction of this group
    my ($previous_bt_id, $previous_acc_trans_id) = ($first_transaction->bank_transaction_id, $first_transaction->acc_trans_id);
    foreach my $linked_transaction (@{ $linked_transactions }) {
      my $bank_transaction = $linked_transaction->bank_transaction;
      my $acc_transaction  = $linked_transaction->acc_tran;
      if (defined $fromdate) {
        $bank_transaction->{class} = 'out_of_balance' if ( $bank_transaction->transdate lt $fromdate );
        $acc_transaction->{class}  = 'out_of_balance' if ( $acc_transaction->transdate  lt $fromdate );
      }
      if (defined $todate) {
        $bank_transaction->{class} = 'out_of_balance' if ( $bank_transaction->transdate gt $todate );
        $acc_transaction->{class}  = 'out_of_balance' if ( $acc_transaction->transdate  gt $todate );
      }
      if ($bank_transaction->id != $previous_bt_id) {
        push @{ $line->{BT} }, $bank_transaction;
      }
      if ($acc_transaction->acc_trans_id != $previous_acc_trans_id) {
        push @{ $line->{BB} }, $acc_transaction;
      }
    }
    push @rows, $line;
  }

  #add non-cleared bank transactions
  my $bank_transactions = SL::DB::Manager::BankTransaction->get_all(where => \@bt_where);
  foreach my $bt (@{ $bank_transactions }) {
    my $line;
    $line->{BT} = [ $bt ];
    $line->{type} = 'BT';
    $line->{id} = $bt->id;
    push @rows, $line;
  }

  #add non-cleared bookings on bank
  my $bookings_on_bank = SL::DB::Manager::AccTransaction->get_all(where => \@bb_where);
  foreach my $bb (@{ $bookings_on_bank }) {
    if ($::form->{filter}->{show_stornos} or !$bb->get_transaction->storno) {
      my $line;
      $line->{BB} = [ $bb ];
      $line->{type} = 'BB';
      $line->{id} = $bb->acc_trans_id;
      push @rows, $line;
    }
  }

  #sort lines
  @rows = sort sort_by_transdate @rows;

  $self->{LINKED_TRANSACTIONS} = \@rows;
}

sub sort_by_transdate {
  if ($a->{BT} and $b->{BT}) {
    return $a->{BT}[0]->amount <=> $b->{BT}[0]->amount if $a->{BT}[0]->transdate eq $b->{BT}[0]->transdate;
    return $a->{BT}[0]->transdate cmp $b->{BT}[0]->transdate;
  }
  if ($a->{BT}) {
    return $a->{BT}[0]->amount <=> (-1 * $b->{BB}[0]->amount) if $a->{BT}[0]->transdate eq $b->{BB}[0]->transdate;
    return $a->{BT}[0]->transdate cmp $b->{BB}[0]->transdate;
  }
  if ($b->{BT}) {
    return (-1 * $a->{BB}[0]->amount) <=> $b->{BT}[0]->amount if $a->{BB}[0]->transdate eq $b->{BT}[0]->transdate;
    return $a->{BB}[0]->transdate cmp $b->{BT}[0]->transdate;
  }
  return (-1 * $a->{BB}[0]->amount) <=> (-1 * $b->{BB}[0]->amount) if $a->{BB}[0]->transdate eq $b->{BB}[0]->transdate;
  return $a->{BB}[0]->transdate cmp $b->{BB}[0]->transdate;
}

sub _get_balances {
  my ($self) = @_;

  $self->_filter_to_where;

  my (@bt_where, @bb_where);
  @bt_where = @{ $self->{bt_where} };
  @bb_where = @{ $self->{bb_where} };

  my $bank_transactions = SL::DB::Manager::BankTransaction->get_all(where => \@bt_where );
  my $payments  = SL::DB::Manager::AccTransaction ->get_all(where => \@bb_where );

  #for absolute balance get all bookings till todate
  my $todate   = $::locale->parse_date_to_object(\%::myconfig, $::form->{filter}->{todate_date__le});

  my @all_bt_where = (local_bank_account_id => $self->{bank_account}->id);
  my @all_bb_where = (chart_id              => $self->{bank_account}->chart_id);

  if ($todate) {
    push @all_bt_where, (transdate => { le => $todate });
    push @all_bb_where, (transdate => { le => $todate });
  }

  my $all_bank_transactions = SL::DB::Manager::BankTransaction->get_all(where => \@all_bt_where);
  my $all_payments  = SL::DB::Manager::AccTransaction ->get_all(where => \@all_bb_where);

  my ($bt_balance, $bb_balance) = (0,0);
  my ($absolut_bt_balance, $absolut_bb_balance) = (0,0);

  map { $bt_balance += $_->amount } @{ $bank_transactions };
  map { $bb_balance += $_->amount if ($::form->{filter}->{show_stornos} or !$_->get_transaction->storno) } @{ $payments };
  map { $absolut_bt_balance += $_->amount } @{ $all_bank_transactions };
  map { $absolut_bb_balance += $_->amount } @{ $all_payments };

  $self->{bt_balance} = $bt_balance || 0;
  $self->{bb_balance} = $bb_balance || 0;
  $self->{absolut_bt_balance} = $absolut_bt_balance || 0;
  $self->{absolut_bb_balance} = $absolut_bb_balance || 0;

  $self->{difference} = $bt_balance + $bb_balance;
}

sub init_cleared {
  [ { title => t8("all"),       value => ''           },
    { title => t8("cleared"),   value => 'TRUE'       },
    { title => t8("uncleared"), value => 'FALSE'      }, ]
}

sub init_BANK_ACCOUNTS {
  SL::DB::Manager::BankAccount->get_all();
}

1;
