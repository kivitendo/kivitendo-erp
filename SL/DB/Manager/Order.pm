package SL::DB::Manager::Order;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::Order' }

__PACKAGE__->make_manager_methods;

sub type_filter {
  my $class = shift;
  my $type  = lc(shift || '');

  return (and => [ '!customer_id' => undef,         quotation => 1                       ]) if $type eq 'sales_quotation';
  return (and => [ '!vendor_id'   => undef,         quotation => 1                       ]) if $type eq 'request_quotation';
  return (and => [ '!customer_id' => undef, or => [ quotation => 0, quotation => undef ] ]) if $type eq 'sales_order';
  return (and => [ '!vendor_id'   => undef, or => [ quotation => 0, quotation => undef ] ]) if $type eq 'purchase_order';

  die "Unknown type $type";
}

1;
