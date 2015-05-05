# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::BankTransaction;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;
use SL::DB::Helper::Filtered;

sub object_class { 'SL::DB::BankTransaction' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'transdate', 1 ],
           columns => { SIMPLE => 'ALL',
                        local_account_number => 'local_bank_account.account_number',
                        local_bank_code      => 'local_bank_account.bank_code' }, );
}

sub default_objects_per_page {
  40;
}

1;
