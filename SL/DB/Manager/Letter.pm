package SL::DB::Manager::Letter;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Filtered;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Letter' }

__PACKAGE__->make_manager_methods;
__PACKAGE__->add_filter_specs(
  is_sales => sub {
    my ($key, $value, $prefix) = @_;
    __PACKAGE__->is_sales_filter($value, $prefix);
  },
);

sub is_sales_filter {
  my ($class, $value, $prefix) = @_;

  return () if !defined $value;
  return ($prefix . 'customer_id' => { gt => 0 }) if $value;
  return ($prefix . 'vendor_id'   => { gt => 0 }) if !$value;
}

sub _sort_spec {
  return ( columns => { SIMPLE    => 'ALL',
                        customer  => [ 'lower(customer.name)', ],
                      },
           default => [ 'date', 0 ],
           nulls   => { }
         );
}

sub default_objects_per_page { 30 }

1;
