package SL::DB::Manager::BankAccount;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::BankAccount' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL' } );
}

sub get_default {
    return $_[0]->get_first(where => [ obsolete => 0 ], sort_by => 'sortkey');
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Manager::BankAccount - RDBO manager for the C<bank_accounts> table

=head1 FUNCTIONS

=over 4

=item C<get_default>

Returns an RDBO instance corresponding to the default bank account. The default
bank account is defined as the bank account with the highest sort order (usually 1) that
is not set to obsolete.

Example:

  my $default_bank_account_id = SL::DB::Manager::BankAccount->get_default->id;

=back

=cut
