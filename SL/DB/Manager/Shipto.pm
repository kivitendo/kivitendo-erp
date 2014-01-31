package SL::DB::Manager::Shipto;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Shipto' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default        => [ 'full_address', 1 ],
    columns        => {
      SIMPLE       => 'ALL',
      full_address => '( lower(shipto.shiptoname) || lower(shipto.shiptostreet) || lower(shipto.shiptocity) )',
      map { ( $_ => "lower(shipto.shipto$_)" ) } qw(city contact country department_1 department_2 email fax name phone street zipcode)
    });
}

1;
