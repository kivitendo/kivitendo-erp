package SL::DB::Manager::ReclamationReason;

use strict;

use parent qw(SL::DB::Helper::Manager);
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Filtered;

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::ReclamationReason' }

__PACKAGE__->make_manager_methods;
__PACKAGE__->add_filter_specs(
  all => sub {
    my ($key, $value, $prefix) = @_;
    return or => [ map { $prefix . $_ => $value } qw(reclamation_reason) ]
  },
);

sub _sort_spec {
  return ( default => [ 'position', 1 ],
           columns => { SIMPLE => 'ALL' });
}
1;
