package SL::DB::Manager::PaymentTerm;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::PaymentTerm' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL',
                        map { ( $_ => "lower(payment_terms.${_})" ) } qw(description description_long description_long_invoice),
                      });
}

1;
