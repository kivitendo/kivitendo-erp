package SL::Controller::AccTrans;
use strict;
use parent qw(SL::Controller::Base);
use SL::DB::AccTransaction;

__PACKAGE__->run_before('check_auth');

sub action_list_transactions {
  my ($self) = @_;

  return $self->render('generic/error', { layout => 0 }, label_error => "list_transactions needs a trans_id") unless $::form->{trans_id};

  my $transactions = SL::DB::Manager::AccTransaction->get_all(query => [ trans_id => $::form->{trans_id} ], sort_by => 'acc_trans_id ASC');

  return $self->render(\'', { type => 'json' }) unless scalar @{$transactions};

  my $acc_trans_table = $self->_mini_ledger($transactions);
  my $balances_table  = $self->_mini_trial_balance($transactions);

  return $self->render('acc_trans/acc_trans', { layout => 0 }, acc_trans_table => $acc_trans_table, balances_table => $balances_table);
}

sub _mini_ledger {
  my ($self, $transactions) = @_;

  $::auth->assert('invoice_edit');

  my $debit_sum  = 0;
  my $credit_sum = 0;

  foreach my $t ( @{ $transactions } ) {
    $debit_sum  += $t->amount if $t->amount < 0;
    $credit_sum += $t->amount if $t->amount > 0;
  };

  return $self->render('acc_trans/_mini_ledger', { output => 0 }, TRANSACTIONS => $transactions, debit_sum => $debit_sum, credit_sum => $credit_sum, title => $::locale->text('Transactions') );
}

sub _mini_trial_balance {
  my ($self, $transactions) = @_;

  $::auth->assert('invoice_edit');

  my $rec = {};
  foreach my $t ( @{ $transactions } ) {
    $rec->{$t->chart->accno}->{description} = $t->chart->description;
    $rec->{$t->chart->accno}->{accno}       = $t->chart->accno;
    $rec->{$t->chart->accno}->{balance}    += $t->amount;
  };

  my @balances;
  foreach ( sort keys %{ $rec } ) {
    push @balances, $rec->{$_} if $rec->{$_}->{balance} != 0;
  };

  return $self->render('acc_trans/_mini_trial_balance', { output => 0 }, BALANCES => \@balances, title => $::locale->text('Balances') );
}

sub check_auth {
  $::auth->assert('invoice_edit');
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::AccTrans - module to list all transactions and balances of an invoice

=head1 SYNOPSIS

  list_transactions takes an id of an invoice and displays all the transactions in two HTML tables:

  * mini_ledger: list of all transactions of the invoice,  showing date, chart info and the amount as debit or credit, like a small general ledger just for this invoice.

  * mini_trial_balance: list of all charts from the transactions with their current sum, shown as debit or credit.

  The two tables are returned as an HTML div blob.

  # sample code for console:
  use SL::Controller::AccTrans;
  # get an invoice (ar/ap/is/ir)
  my $invoice = SL::DB::Manager::Invoice->find_by( invnumber => 1 );
  # the function is called from an opened invoice and needs the trans_id as a parameter
  $::form->{trans_id} = $invoice->id;
  SL::Controller::AccTrans->action_list_transactions();

  The HTML blob can also be opened directly as a url:
  controller.pl?action=AccTrans/list_transactions&trans_id=7

=head1 TODO

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
