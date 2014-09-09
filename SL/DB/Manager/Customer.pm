package SL::DB::Manager::Customer;

use strict;

use SL::DB::Helper::Manager;
use SL::DB::Helper::Sorted;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Filtered;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::Customer' }

__PACKAGE__->make_manager_methods;

__PACKAGE__->add_filter_specs(
  all => sub {
    my ($key, $value, $prefix) = @_;
    return or => [ map { $prefix . $_ => $value } qw(customernumber name) ]
  }
);

sub _sort_spec {
  return ( default => [ 'name', 1 ],
           columns => { SIMPLE => 'ALL',
                        map { ( $_ => "lower(customer.$_)" ) } qw(customernumber vendornumber name contact phone fax email street taxnumber business invnumber ordnumber quonumber)
                      });
}

1;
