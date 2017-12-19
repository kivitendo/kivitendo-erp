package SL::Presenter::BankAccount;

use strict;

use SL::Presenter::EscapedText qw(escape);

use Exporter qw(import);
our @EXPORT_OK = qw(account_number bank_code);

use Carp;

sub account_number {
  my ($bank_account) = @_;
  escape($bank_account->account_number);
}

sub bank_code {
  my ($bank_account) = @_;
  escape($bank_account->bank_code);
}

1;
