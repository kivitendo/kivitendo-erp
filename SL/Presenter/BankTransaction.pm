package SL::Presenter::BankTransaction;

use strict;
use utf8;

use SL::Locale::String qw(t8);
use SL::Presenter::EscapedText qw(escape);

use Exporter qw(import);
our @EXPORT_OK = qw(show bank_transaction);

use Carp;

sub show {goto &bank_account};

sub bank_transaction {
  my ($bank_transaction) = @_;
  my $bank_account = $bank_transaction->local_bank_account;

  escape(join ' ', (
    t8('Bank transaction'),
    $bank_transaction->transdate . ":",
    $bank_account->bank_code,
    $bank_account->account_number,
    "→",
    $bank_transaction->remote_bank_code,
    $bank_transaction->remote_account_number,
    "-",
    $bank_transaction->amount . $bank_transaction->currency->name,
  ));
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::BankTransaction - Presenter module for SL::DB::BankTransaction objects

=head1 SYNOPSIS

  my $object = SL::DB::Manager::BankTransaction->get_first();
  my $html   = SL::Presenter::BankTransaction::bank_transaction($object);
  # or
  my $html   = $object->presenter->show();

=head1 FUNCTIONS

=over 4

=item C<show $object>

Alias for C<bank_transaction $object>.

=item C<bank_transaction $object>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the bank transaction object
C<$object>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
