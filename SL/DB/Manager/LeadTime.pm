# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::LeadTime;

use strict;

use SL::DB::Helper::Manager;
use SL::DB::Helper::Sorted;
use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::LeadTime' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL' } );
}

sub get_valid {
  my ($class, $with_this_id) = @_;

  my @conditions = (obsolete => 0);

  if ($with_this_id) {
    @conditions = (
      or => [
        id => $with_this_id,
        @conditions,
      ]);
  }

  return $class->get_all_sorted(query => \@conditions);
}


1;
