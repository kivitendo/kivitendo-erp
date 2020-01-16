package SL::DB::Manager::Bin;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;
use SL::DB::Helper::Filtered;

sub object_class { 'SL::DB::Bin' }

__PACKAGE__->make_manager_methods;
__PACKAGE__->add_filter_specs(
  all => sub {
    my ($key, $value, $prefix) = @_;
    return or => [ map { $prefix . $_ => $value } qw(description) ]
  }
);

sub _sort_spec {
  return (
    default        => [ 'description', 1 ],
    columns        => {
      SIMPLE       => 'ALL',
    });
}
1;
