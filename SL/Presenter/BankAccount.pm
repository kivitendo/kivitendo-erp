package SL::Presenter::BankAccount;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(account_number bank_code);

use Carp;

sub account_number {
  my ($self, $bank_account) = @_;
  return $self->escaped_text($bank_account->account_number);
}

sub bank_code {
  my ($self, $bank_account) = @_;
  return $self->escaped_text($bank_account->bank_code);
}

1;
