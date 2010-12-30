package SL::DB::Manager::DeliveryOrder;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::DeliveryOrder' }

__PACKAGE__->make_manager_methods;

sub type_filter {
  my $class = shift;
  my $type  = lc(shift || '');

  return ('!customer_id' => undef) if $type eq 'sales_delivery_order';
  return ('!vendor_id'   => undef) if $type eq 'purchase_delivery_order';

  die "Unknown type $type";
}

1;
